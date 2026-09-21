-- CreateEnum
CREATE TYPE "OrganizationType" AS ENUM ('HOSPITAL', 'CLINIC', 'DIAGNOSTIC_CENTER', 'POLYCLINIC', 'OTHER');

-- CreateEnum
CREATE TYPE "OrganizationVerificationStatus" AS ENUM ('DRAFT', 'PENDING_VERIFICATION', 'VERIFIED', 'REJECTED');

-- AlterTable
ALTER TABLE "Organization" ADD COLUMN     "about" TEXT,
ADD COLUMN     "coverImageUrl" TEXT,
ADD COLUMN     "isPubliclyListed" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "logoUrl" TEXT,
ADD COLUMN     "orgType" "OrganizationType",
ADD COLUMN     "publicEmail" TEXT,
ADD COLUMN     "publicPhone" TEXT,
ADD COLUMN     "tagline" TEXT,
ADD COLUMN     "verificationStatus" "OrganizationVerificationStatus" NOT NULL DEFAULT 'DRAFT',
ADD COLUMN     "website" TEXT;
