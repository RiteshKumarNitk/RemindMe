-- At most one self-owned Patient record per (organization, user). Postgres
-- treats NULL as distinct across rows in a unique index, so this never
-- restricts clinic-registered dependents (ownerUserId IS NULL) — only a
-- genuine duplicate self-owned record for the same person at the same
-- clinic. Backs the self-service "become a patient of this clinic" upsert
-- (src/modules/patient-booking/service.ts).
DROP INDEX "Patient_organizationId_ownerUserId_idx";

CREATE UNIQUE INDEX "Patient_organizationId_ownerUserId_key" ON "Patient"("organizationId", "ownerUserId");
