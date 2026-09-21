import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Pin the tracing root (this dir has its own lockfile; a stray one exists in $HOME).
  outputFileTracingRoot: here,
  serverExternalPackages: ["@node-rs/argon2", "@prisma/client"],
  // Types are checked in CI via `tsc --noEmit`; ESLint is not set up in Phase 1.
  eslint: { ignoreDuringBuilds: true },
  webpack(config) {
    // Allow NodeNext-style `.js` specifiers to resolve to `.ts`/`.tsx` sources,
    // matching tsconfig `moduleResolution: "Bundler"` and vitest.
    config.resolve.extensionAlias = {
      ".js": [".ts", ".tsx", ".js"],
      ".mjs": [".mts", ".mjs"],
      ".cjs": [".cts", ".cjs"],
    };
    return config;
  },
};

export default nextConfig;
