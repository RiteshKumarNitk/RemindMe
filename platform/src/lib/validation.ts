import { z } from "zod";
import { AppError } from "./errors.js";

/**
 * A URL field that will later be rendered as an `<a href>`/`<img src>` (org
 * website/logo/cover, doctor photo, ...). `z.string().url()` alone accepts any
 * scheme the WHATWG URL parser recognizes, including `javascript:` — a stored
 * XSS vector once such a value round-trips through a public, unauthenticated
 * page. Restricting to http(s) at the validation boundary is the fix, not
 * escaping at render time (there's nothing to escape; the danger is the scheme
 * itself, not markup).
 */
export function httpUrlSchema(maxLength: number) {
  return z
    .string()
    .max(maxLength)
    .refine((v) => /^https?:\/\//i.test(v) && z.string().url().safeParse(v).success, {
      message: "Must be a valid http(s) URL.",
    });
}

function issuesOf(err: z.ZodError) {
  return err.issues.map((i) => ({ path: i.path.join("."), message: i.message }));
}

/** Parse+validate a JSON request body; 400 on bad JSON, 422 on schema errors. */
export async function parseBody<S extends z.ZodTypeAny>(
  req: Request,
  schema: S,
): Promise<z.infer<S>> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    throw new AppError("MALFORMED_REQUEST", "Request body is not valid JSON.");
  }
  const result = schema.safeParse(raw);
  if (!result.success) {
    throw new AppError("VALIDATION_FAILED", "Request validation failed.", {
      issues: issuesOf(result.error),
    });
  }
  return result.data;
}

/** Validate URL search params against a schema. */
export function parseQuery<S extends z.ZodTypeAny>(url: string, schema: S): z.infer<S> {
  const params = Object.fromEntries(new URL(url).searchParams.entries());
  const result = schema.safeParse(params);
  if (!result.success) {
    throw new AppError("VALIDATION_FAILED", "Query validation failed.", {
      issues: issuesOf(result.error),
    });
  }
  return result.data;
}

export { z };
