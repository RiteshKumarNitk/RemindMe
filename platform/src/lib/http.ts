import { randomUUID } from "node:crypto";
import type { Role } from "@prisma/client";
import { db } from "./db.js";
import { env } from "./env.js";
import { AppError, toEnvelope } from "./errors.js";
import { checkRateLimit, type RateClass } from "./rate-limit.js";
import { authenticate } from "./auth/authenticate.js";
import type { RequestContext } from "./context.js";

const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Cache-Control": "no-store",
};
if (env.NODE_ENV === "production") {
  SECURITY_HEADERS["Strict-Transport-Security"] =
    "max-age=31536000; includeSubDomains";
}

export function json(
  body: unknown,
  init: { status?: number; headers?: Record<string, string> } = {},
): Response {
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: {
      "Content-Type": "application/json",
      ...SECURITY_HEADERS,
      ...init.headers,
    },
  });
}

export interface HandlerArgs<P extends Record<string, string> = Record<string, string>> {
  req: Request;
  ctx: RequestContext;
  params: P;
}

export interface WithApiOptions {
  auth?: "required" | "optional" | "none";
  roles?: Role[];
  rateClass?: RateClass;
}

type NextRouteContext = { params: Promise<Record<string, string | string[] | undefined>> };

function clientIp(req: Request): string | null {
  return (
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("x-real-ip") ??
    null
  );
}

/**
 * Wraps a route handler with the request pipeline (SYSTEM_ARCHITECTURE.md):
 * rate-limit → authenticate → resolve tenant (from :orgId path param ONLY) →
 * role gate → handler → typed error envelope.
 */
export function withApi<P extends Record<string, string> = Record<string, string>>(
  options: WithApiOptions,
  handler: (args: HandlerArgs<P>) => Promise<Response>,
): (req: Request, routeCtx: NextRouteContext) => Promise<Response> {
  const authMode = options.auth ?? "required";

  return async (req, routeCtx) => {
    const requestId = randomUUID();
    const ip = clientIp(req);
    const userAgent = req.headers.get("user-agent");
    const params = ((await routeCtx?.params) ?? {}) as P;

    try {
      checkRateLimit(ip ?? "anon", options.rateClass ?? "default");

      const authed = authMode === "none" ? null : await authenticate(req);
      if (authMode === "required" && !authed) {
        throw new AppError("NOT_AUTHENTICATED", "Authentication required.");
      }

      const ctx: RequestContext = {
        userId: authed?.userId ?? "",
        isPlatformAdmin: authed?.isPlatformAdmin ?? false,
        isGuest: authed?.isGuest ?? false,
        requestId,
        ip,
        userAgent,
      };

      // Tenant resolution — ONLY from the :orgId path segment, matched against
      // the caller's ACTIVE memberships. No header, no body value is trusted.
      const orgId = params.orgId;
      if (orgId) {
        if (!authed) {
          throw new AppError("NOT_AUTHENTICATED", "Authentication required.");
        }
        const membership = await db.membership.findFirst({
          where: { userId: authed.userId, organizationId: orgId, status: "ACTIVE" },
          include: { organization: { select: { isActive: true } } },
        });
        if (!membership) {
          // No leak: same as a non-existent org.
          throw new AppError("NOT_FOUND", "Not found.");
        }
        ctx.org = {
          id: orgId,
          membershipId: membership.id,
          role: membership.role,
          capabilities: membership.capabilities,
          isActive: membership.organization.isActive,
        };
        if (options.roles && !options.roles.includes(membership.role)) {
          throw new AppError(
            "FORBIDDEN_ROLE",
            `This action requires role: ${options.roles.join(" or ")}.`,
          );
        }
      }

      const res = await handler({ req, ctx, params });
      for (const [k, v] of Object.entries(SECURITY_HEADERS)) {
        if (!res.headers.has(k)) res.headers.set(k, v);
      }
      return res;
    } catch (err) {
      if (err instanceof AppError) {
        const headers: Record<string, string> = {};
        if (err.code === "RATE_LIMITED") {
          const ra = (err.details as { retryAfter?: number })?.retryAfter;
          if (ra) headers["Retry-After"] = String(ra);
        }
        return json(toEnvelope(err), { status: err.status, headers });
      }
      // Unknown → generic 500; real cause only in the server log.
      console.error(`[${requestId}] unhandled error:`, err);
      return json(
        {
          error: {
            code: "INTERNAL",
            message: "Something went wrong.",
            details: { requestId },
          },
        },
        { status: 500 },
      );
    }
  };
}
