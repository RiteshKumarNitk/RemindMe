import { AppError } from "@/lib/errors.js";
import { withApi } from "@/lib/http.js";

/**
 * Platform guest mode (GUEST_ACCESS.md) — sandboxed demo-org preview.
 * Deferred to a later phase: requires the seeded demo organization and the
 * `allowDemoWalkthrough` policy branch. The contract slot exists so clients
 * can detect availability.
 */
export const POST = withApi({ auth: "none", rateClass: "auth" }, async () => {
  throw new AppError(
    "NOT_IMPLEMENTED",
    "Guest/demo access is not available yet.",
  );
});
