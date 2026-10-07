-- =============================================================================
-- Push notifications + "clinics near me". Purely additive.
--
--   1. ClinicLocation gains optional latitude/longitude.
--   2. DeviceToken: FCM registration tokens per user.
-- =============================================================================

-- 1. Coordinates
ALTER TABLE "ClinicLocation" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "ClinicLocation" ADD COLUMN "longitude" DOUBLE PRECISION;

-- 2. Device tokens
CREATE TABLE "DeviceToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DeviceToken_token_key" ON "DeviceToken"("token");
CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken"("userId");

ALTER TABLE "DeviceToken" ADD CONSTRAINT "DeviceToken_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
