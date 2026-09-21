import { hash, verify } from "@node-rs/argon2";
import { env } from "../env.js";

/**
 * Password hashing — argon2id (AUTHENTICATION.md R1). `@node-rs/argon2`
 * defaults `algorithm` to Argon2id, so we don't reference the const enum
 * (blocked by `isolatedModules`). Parameters from env; a stale-param hash is
 * transparently re-hashed on the next successful login.
 */
const opts = {
  memoryCost: env.ARGON2_MEMORY_KIB,
  timeCost: env.ARGON2_TIME_COST,
  parallelism: env.ARGON2_PARALLELISM,
} as const;

export function hashPassword(plain: string): Promise<string> {
  return hash(plain, opts);
}

export async function verifyPassword(
  hashString: string,
  plain: string,
): Promise<boolean> {
  try {
    return await verify(hashString, plain);
  } catch {
    return false;
  }
}

/** True when the stored hash was produced with weaker params than current. */
export function needsRehash(hashString: string): boolean {
  const m = /\$argon2id\$v=\d+\$m=(\d+),t=(\d+),p=(\d+)\$/.exec(hashString);
  if (!m) return true;
  const [, mem, time, par] = m;
  return (
    Number(mem) < env.ARGON2_MEMORY_KIB ||
    Number(time) < env.ARGON2_TIME_COST ||
    Number(par) < env.ARGON2_PARALLELISM
  );
}
