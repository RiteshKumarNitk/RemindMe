type Handler = (
  req: Request,
  routeCtx: { params: Promise<Record<string, string | string[] | undefined>> },
) => Promise<Response>;

export interface CallOptions {
  method?: string;
  url?: string;
  headers?: Record<string, string>;
  body?: unknown;
  params?: Record<string, string>;
  bearer?: string;
  cookie?: string;
  client?: "web" | "app";
}

export interface CallResult<T = unknown> {
  status: number;
  body: T;
  headers: Headers;
  res: Response;
}

export async function call<T = unknown>(
  handler: Handler,
  opts: CallOptions = {},
): Promise<CallResult<T>> {
  const headers = new Headers(opts.headers ?? {});
  if (opts.bearer) headers.set("authorization", `Bearer ${opts.bearer}`);
  if (opts.cookie) headers.set("cookie", opts.cookie);
  if (opts.client) headers.set("x-client", opts.client);
  if (opts.body !== undefined && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  // Give the rate limiter a unique-ish identity per test call.
  if (!headers.has("x-forwarded-for")) {
    headers.set("x-forwarded-for", `10.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}`);
  }

  const req = new Request(opts.url ?? "http://test.local/api", {
    method: opts.method ?? (opts.body !== undefined ? "POST" : "GET"),
    headers,
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });

  const res = await handler(req, { params: Promise.resolve(opts.params ?? {}) });
  const text = await res.text();
  let body: unknown = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body: body as T, headers: res.headers, res };
}

/** Extract the raw dw_session token from a Set-Cookie header. */
export function sessionCookieFrom(headers: Headers): string | null {
  const sc = headers.get("set-cookie");
  if (!sc) return null;
  const m = /dw_session=([^;]+)/.exec(sc);
  return m ? `dw_session=${m[1]}` : null;
}
