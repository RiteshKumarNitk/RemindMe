import { z } from "zod";

/**
 * Validated view of process.env. Import `env` anywhere instead of touching
 * process.env directly. Throws at startup if required vars are missing.
 */
const schema = z.object({
  DATABASE_URL: z.string().url(),
  DIRECT_URL: z.string().url().optional(),

  AUTH_SESSION_SECRET: z.string().min(24),
  JWT_ACCESS_SECRET: z.string().min(24),
  JWT_REFRESH_SECRET: z.string().min(24),
  JWT_ACCESS_TTL: z.coerce.number().int().positive().default(900),
  JWT_REFRESH_TTL: z.coerce.number().int().positive().default(2_592_000),
  JWT_ISSUER: z.string().default("dosewise-platform"),

  ARGON2_MEMORY_KIB: z.coerce.number().int().positive().default(19_456),
  ARGON2_TIME_COST: z.coerce.number().int().positive().default(2),
  ARGON2_PARALLELISM: z.coerce.number().int().positive().default(1),

  GOOGLE_CLIENT_ID: z.string().default(""),
  GOOGLE_CLIENT_SECRET: z.string().default(""),
  GOOGLE_OAUTH_REDIRECT_URL: z
    .string()
    .default("http://localhost:3000/api/auth/google/callback"),

  APP_BASE_URL: z.string().url().default("http://localhost:3000"),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  CORS_ALLOWED_ORIGINS: z.string().default("http://localhost:3000"),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),

  RATE_LIMIT_AUTH_PER_MIN: z.coerce.number().int().positive().default(10),
  RATE_LIMIT_DEFAULT_PER_MIN: z.coerce.number().int().positive().default(120),

  NOTIFICATIONS_CRON_SECRET: z.string().default(""),
  NOTIFICATIONS_DISPATCH_BATCH: z.coerce.number().int().positive().default(100),
  NOTIFICATIONS_CLAIM_TIMEOUT_MIN: z.coerce.number().int().positive().default(10),
  NOTIFICATIONS_MAX_ATTEMPTS: z.coerce.number().int().positive().default(5),
  NOTIFICATIONS_INPROCESS_DISPATCH: z
    .enum(["true", "false"])
    .default("false"),

  STORAGE_PROVIDER: z
    .enum(["local-dev", "s3", "gcs"])
    .default("local-dev"),

  ALLOW_DB_TESTS: z.string().optional(),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  // Never print values — only the offending keys.
  const keys = parsed.error.issues.map((i) => i.path.join(".")).join(", ");
  throw new Error(`Invalid or missing environment variables: ${keys}`);
}

export const env = parsed.data;

export const googleOAuthConfigured =
  env.GOOGLE_CLIENT_ID.length > 0 && env.GOOGLE_CLIENT_SECRET.length > 0;

export const corsOrigins = env.CORS_ALLOWED_ORIGINS.split(",")
  .map((s) => s.trim())
  .filter(Boolean);
