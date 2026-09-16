/**
 * Validate a client-supplied post-login redirect target. Only ever allows a
 * same-app relative path — never an absolute URL or protocol-relative
 * `//host` (both are classic open-redirect vectors), so `?next=` on
 * `/login`/`/register` can't be used to bounce a session cookie holder off
 * to an attacker-controlled site after a real login.
 */
export function safeNextPath(next: string | undefined | null): string {
  if (!next) return "/dashboard";
  if (!next.startsWith("/") || next.startsWith("//") || next.includes("://")) {
    return "/dashboard";
  }
  return next;
}
