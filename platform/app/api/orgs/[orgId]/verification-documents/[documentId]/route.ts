import { AppError } from "@/lib/errors.js";
import { authenticate } from "@/lib/auth/authenticate.js";
import { resolveOrgContext } from "@/lib/org-context.js";
import type { RequestContext } from "@/lib/context.js";
import { getVerificationDocumentBytes } from "@/modules/verification-documents/service.js";

export const dynamic = "force-dynamic";

/**
 * Download a verification document. Deliberately a plain route, not `withApi`:
 * the document is addressed by org + document id, and the two legitimate
 * audiences (the owning clinic's CLINIC_ADMIN, any platform admin) don't map
 * onto `withApi`'s single :orgId membership resolution — a platform admin has
 * no membership in the org, and `withApi` would 404 them before the handler
 * could allow the review path. Auth + audience checks happen here explicitly;
 * the service re-checks them (defense in depth).
 */
export async function GET(
  req: Request,
  routeCtx: { params: Promise<{ orgId: string; documentId: string }> },
) {
  try {
    const { orgId, documentId } = await routeCtx.params;
    const authed = await authenticate(req);
    if (!authed) throw new AppError("NOT_AUTHENTICATED", "Authentication required.");

    const ctx: RequestContext = {
      userId: authed.userId,
      isPlatformAdmin: authed.isPlatformAdmin,
      isGuest: authed.isGuest,
      requestId: "verification-doc-download",
      ip: null,
      userAgent: req.headers.get("user-agent"),
    };

    // Non-platform callers must hold an ACTIVE membership in this org (the
    // service then narrows to CLINIC_ADMIN of exactly this org).
    if (!authed.isPlatformAdmin) {
      const org = await resolveOrgContext(authed.userId, orgId);
      if (!org) throw new AppError("NOT_FOUND", "Not found.");
      ctx.org = org;
    }

    const { fileName, mimeType, data } = await getVerificationDocumentBytes(ctx, orgId, documentId);
    return new Response(Buffer.from(data), {
      headers: {
        "Content-Type": mimeType,
        "Content-Disposition": `inline; filename="${encodeURIComponent(fileName)}"`,
        "Content-Length": String(data.byteLength),
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
      },
    });
  } catch (err) {
    const status = err instanceof AppError ? err.status : 500;
    const code = err instanceof AppError ? err.code : "INTERNAL";
    const message = err instanceof AppError ? err.message : "Something went wrong.";
    return new Response(JSON.stringify({ error: { code, message } }), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  }
}
