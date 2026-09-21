import { describe, expect, it } from "vitest";
import { safeNextPath } from "@/lib/safe-redirect.js";

describe("safeNextPath (open-redirect guard for /login,/register ?next=)", () => {
  it("passes through a plain same-app relative path", () => {
    expect(safeNextPath("/doctors/abc/book?slot=x")).toBe("/doctors/abc/book?slot=x");
  });

  it("defaults to /dashboard when missing", () => {
    expect(safeNextPath(undefined)).toBe("/dashboard");
    expect(safeNextPath(null)).toBe("/dashboard");
    expect(safeNextPath("")).toBe("/dashboard");
  });

  it("rejects a protocol-relative //host (classic open-redirect vector)", () => {
    expect(safeNextPath("//evil.example/phish")).toBe("/dashboard");
  });

  it("rejects an absolute URL with any scheme", () => {
    expect(safeNextPath("https://evil.example/phish")).toBe("/dashboard");
    expect(safeNextPath("javascript://evil.example")).toBe("/dashboard");
  });

  it("rejects a path with no leading slash", () => {
    expect(safeNextPath("dashboard")).toBe("/dashboard");
  });
});
