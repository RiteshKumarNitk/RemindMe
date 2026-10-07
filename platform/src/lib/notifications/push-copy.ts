/**
 * Patient-facing push wording per event. `null` = this event is not pushed.
 * Kept beside the sender so copy and delivery evolve together; the in-app
 * bell has its own wording in the notifications module.
 */
export function pushCopy(
  event: string,
  payload: unknown,
): { title: string; body: string; data: Record<string, string> } | null {
  const p = (payload ?? {}) as Record<string, unknown>;
  const appointmentId = typeof p.appointmentId === "string" ? p.appointmentId : "";
  const data = { event, appointmentId };
  const token = typeof p.tokenNumber === "number" ? ` #${p.tokenNumber}` : "";

  switch (event) {
    case "APPOINTMENT_BOOKED":
      return {
        title: "Appointment booked",
        body: "Your appointment is confirmed. Tap to view the details.",
        data,
      };
    case "APPOINTMENT_CANCELLED":
      return { title: "Appointment cancelled", body: "Your appointment was cancelled.", data };
    case "APPOINTMENT_RESCHEDULED":
      return {
        title: "Appointment rescheduled",
        body: "Your appointment has a new time. Tap to view it.",
        data,
      };
    case "APPOINTMENT_REMINDER": {
      const when = p.label === "T-2H" ? "in 2 hours" : p.label === "T-24H" ? "tomorrow" : "soon";
      return { title: "Appointment reminder", body: `You have an appointment ${when}.`, data };
    }
    case "CHECK_IN_CONFIRMED":
      return {
        title: "Checked in",
        body: "You are in the queue. We will tell you when it is your turn.",
        data,
      };
    case "QUEUE_UPDATE":
      switch (p.state) {
        case "WAITING":
          return {
            title: `Token${token} confirmed`,
            body: "You are in the queue. Track it live in the app.",
            data,
          };
        case "CALLED":
          return {
            title: "It is your turn",
            body: `Token${token}: please go to the consultation room now.`,
            data,
          };
        case "HOLD":
          return { title: "Your place is on hold", body: "Please speak to reception.", data };
        case "SKIPPED":
          return {
            title: "You were called",
            body: "We missed you. Please see reception to be called again.",
            data,
          };
        case "NO_SHOW":
          return {
            title: "Marked as not arrived",
            body: "Please contact the clinic if this is wrong.",
            data,
          };
        default:
          return { title: "Queue update", body: "Your place in the queue changed.", data };
      }
    default:
      return null;
  }
}
