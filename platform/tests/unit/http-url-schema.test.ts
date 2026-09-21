import { describe, expect, it } from "vitest";
import { httpUrlSchema } from "@/lib/validation.js";

describe("httpUrlSchema (stored-XSS guard for website/logoUrl/coverImageUrl/photoUrl)", () => {
  const schema = httpUrlSchema(500);

  it("accepts a plain https URL", () => {
    expect(schema.safeParse("https://example-clinic.com").success).toBe(true);
  });

  it("accepts a plain http URL", () => {
    expect(schema.safeParse("http://example-clinic.com").success).toBe(true);
  });

  it("rejects a javascript: URI (would render as an unsanitized <a href>)", () => {
    expect(schema.safeParse("javascript:alert(document.cookie)").success).toBe(false);
  });

  it("rejects a data: URI", () => {
    expect(schema.safeParse("data:text/html,<script>alert(1)</script>").success).toBe(false);
  });

  it("rejects a bare string with no scheme", () => {
    expect(schema.safeParse("example.com").success).toBe(false);
  });

  it("rejects a value over the length limit", () => {
    expect(schema.safeParse(`https://example.com/${"a".repeat(500)}`).success).toBe(false);
  });
});
