import { describe, expect, it } from "vitest";
import { pushCopy } from "@/lib/notifications/push-copy.js";

describe("pushCopy", () => {
  it("tells the patient it is their turn when called", () => {
    const copy = pushCopy("QUEUE_UPDATE", { appointmentId: "a1", tokenNumber: 12, state: "CALLED" });
    expect(copy?.title).toBe("It is your turn");
    expect(copy?.body).toContain("#12");
    expect(copy?.data).toEqual({ event: "QUEUE_UPDATE", appointmentId: "a1" });
  });

  it("words reminders by their label", () => {
    expect(pushCopy("APPOINTMENT_REMINDER", { label: "T-2H" })?.body).toContain("in 2 hours");
    expect(pushCopy("APPOINTMENT_REMINDER", { label: "T-24H" })?.body).toContain("tomorrow");
  });

  it("only sends string data (FCM requirement)", () => {
    const copy = pushCopy("APPOINTMENT_BOOKED", { appointmentId: 42 });
    for (const v of Object.values(copy!.data)) expect(typeof v).toBe("string");
  });

  it("does not push unknown/staff events", () => {
    expect(pushCopy("SOMETHING_INTERNAL", {})).toBeNull();
  });
});
