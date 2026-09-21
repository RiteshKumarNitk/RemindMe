import { env } from "./env.js";
import { AppError } from "./errors.js";

/**
 * In-process fixed-window rate limiter (SECURITY.md "Rate limiting").
 * Known MVP limitation: not shared across instances — a shared store is
 * required before horizontal scaling (ROADMAP).
 */
type Bucket = { count: number; resetAt: number };
const buckets = new Map<string, Bucket>();

// Opportunistic cleanup so the Map can't grow unbounded.
let lastSweep = 0;
function sweep(now: number) {
  if (now - lastSweep < 60_000) return;
  lastSweep = now;
  for (const [k, b] of buckets) if (b.resetAt <= now) buckets.delete(k);
}

export type RateClass = "auth" | "default";

export function checkRateLimit(identity: string, cls: RateClass = "default"): void {
  const now = Date.now();
  sweep(now);
  const limit =
    cls === "auth"
      ? env.RATE_LIMIT_AUTH_PER_MIN
      : env.RATE_LIMIT_DEFAULT_PER_MIN;
  const key = `${cls}:${identity}`;
  const existing = buckets.get(key);
  if (!existing || existing.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + 60_000 });
    return;
  }
  existing.count += 1;
  if (existing.count > limit) {
    const retryAfter = Math.max(1, Math.ceil((existing.resetAt - now) / 1000));
    throw new AppError(
      "RATE_LIMITED",
      `Too many requests. Retry in ${retryAfter}s.`,
      { retryAfter },
    );
  }
}

/** Test hook. */
export function __resetRateLimiter() {
  buckets.clear();
  lastSweep = 0;
}
