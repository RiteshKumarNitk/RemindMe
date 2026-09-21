import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig } from "vitest/config";

// Load platform/.env into process.env before any test module (which imports
// src/lib/env.ts at eval time) is evaluated. Zero-dep .env parser.
try {
  const raw = readFileSync(resolve(__dirname, ".env"), "utf8");
  for (const line of raw.split("\n")) {
    const m = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (!m) continue;
    const key = m[1]!;
    let val = m[2]!.trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = val;
  }
} catch {
  // no .env — CI is expected to provide vars directly
}
process.env.NODE_ENV = "test";

export default defineConfig({
  resolve: {
    alias: { "@": resolve(__dirname, "src") },
  },
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    fileParallelism: false,
    hookTimeout: 60_000,
    testTimeout: 30_000,
  },
});
