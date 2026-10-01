import { describe, expect, it } from "vitest";
import {
  canQueueTransition,
  hasUnfinishedCall,
  nextQueueState,
} from "../../src/modules/queue/state-machine.js";

describe("queue state machine — token workflow", () => {
  it("a called patient who does not answer can be put on HOLD", () => {
    expect(nextQueueState("CALLED", "HOLD")).toBe("HOLD");
  });

  it("a waiting patient can be held before being called", () => {
    expect(nextQueueState("WAITING", "HOLD")).toBe("HOLD");
  });

  it("RECALL from HOLD calls the patient again (HOLD -> CALLED)", () => {
    expect(nextQueueState("HOLD", "RECALL")).toBe("CALLED");
  });

  it("RELEASE from HOLD puts the patient back in line without calling", () => {
    expect(nextQueueState("HOLD", "RELEASE")).toBe("WAITING");
  });

  it("existing RECALL semantics are unchanged for CALLED and SKIPPED", () => {
    expect(nextQueueState("CALLED", "RECALL")).toBe("WAITING");
    expect(nextQueueState("SKIPPED", "RECALL")).toBe("WAITING");
  });

  it("HOLD, SKIPPED and NO_SHOW are distinct states", () => {
    expect(nextQueueState("WAITING", "HOLD")).not.toBe(nextQueueState("WAITING", "SKIP"));
    expect(nextQueueState("WAITING", "SKIP")).not.toBe(nextQueueState("WAITING", "NO_SHOW"));
  });

  it("NO_SHOW and COMPLETED are terminal", () => {
    for (const a of ["CALL", "RECALL", "HOLD", "RELEASE", "SKIP", "START"] as const) {
      expect(canQueueTransition("NO_SHOW", a)).toBe(false);
      expect(canQueueTransition("COMPLETED", a)).toBe(false);
    }
  });

  it("an in-consultation patient cannot be held or skipped", () => {
    expect(canQueueTransition("IN_CONSULTATION", "HOLD")).toBe(false);
    expect(canQueueTransition("IN_CONSULTATION", "SKIP")).toBe(false);
    expect(() => nextQueueState("IN_CONSULTATION", "HOLD")).toThrow();
  });

  it("a held patient does not block call-next; a called one does", () => {
    expect(hasUnfinishedCall([{ state: "HOLD" }, { state: "WAITING" }])).toBe(false);
    expect(hasUnfinishedCall([{ state: "CALLED" }])).toBe(true);
    expect(hasUnfinishedCall([{ state: "IN_CONSULTATION" }])).toBe(true);
  });
});
