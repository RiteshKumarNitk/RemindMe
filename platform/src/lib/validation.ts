import { z } from "zod";
import { AppError } from "./errors.js";

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
