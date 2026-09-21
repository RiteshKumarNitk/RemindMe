-- AlterTable
ALTER TABLE "DoctorProfile" ADD COLUMN     "consultationFeeMinor" INTEGER,
ADD COLUMN     "isPubliclyListed" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "languages" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "photoUrl" TEXT,
ADD COLUMN     "qualifications" TEXT,
ADD COLUMN     "yearsOfExperience" INTEGER;
