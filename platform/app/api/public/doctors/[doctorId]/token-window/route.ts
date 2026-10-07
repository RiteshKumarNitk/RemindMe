import { json, publicCache, withApi } from "@/lib/http.js";
import { getTokenWindow } from "@/modules/tokens/service.js";

/**
 * A doctor's live same-day token window — open/closed, today's times, and
 * whether a patient could book right now.
 *
 * Unauthenticated, like the rest of `/api/public/doctors/...`, so a discovery
 * page can decide whether to show an enabled "Get a token" button or a disabled
 * "opens at 09:00" one. It reads the same `computeTokenWindow` the booking
 * endpoint enforces, so the two can never disagree.
 *
 * Errors carry the specific code (TOKEN_BOOKING_NOT_OPEN / _CLOSED /
 * _UNAVAILABLE / TOKEN_LIMIT_REACHED) plus the window times in `details`, so a
 * client can render the reason without parsing prose.
 */
export const GET = withApi({ auth: "none" }, async ({ params }) => {
  return json(await getTokenWindow(params.doctorId!), { headers: publicCache(10, 20) });
});