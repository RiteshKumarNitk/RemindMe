import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

/** URL-safe random token (raw secret; only its hash is ever stored). */
export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString("base64url");
}

/** Lowercase hex SHA-256. */
export function sha256hex(input: string): string {
  return createHash("sha256").update(input, "utf8").digest("hex");
}

/** Constant-time string compare (returns false on length mismatch). */
export function timingSafeEqualStr(a: string, b: string): boolean {
  const ab = Buffer.from(a, "utf8");
  const bb = Buffer.from(b, "utf8");
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}
