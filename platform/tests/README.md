# `platform/tests/` — Phase 0 test artifacts

These are **committed now, not yet wired into a runner.** `platform/` has no
`package.json` yet (Phase 1). Each file is written to run unchanged once the
project is scaffolded.

| File | Kind | Needs | Proves |
|---|---|---|---|
| `double-booking.constraint.test.ts` | DB contract (Vitest + `@prisma/client`) | a migrated test DB **including** the EXCLUDE constraint SQL; no app layer | same-clinic overlap rejected; same doctor across clinics allowed; adjacent slots allowed; `CANCELLED` frees the range |

The full required suite (tenant isolation, RBAC incl. capability-gated
`CLINIC_ADMIN`, auth/refresh-rotation/reuse-detection, appointment lifecycle,
availability, queue, family grants, medication sync, audit, invitations, error
hygiene, guest sandboxing) is specified in [`../docs/TESTING.md`](../docs/TESTING.md)
and is built in Phase 1 alongside the modules it exercises.

## Running (once scaffolded)

```bash
cd platform
npm install
createdb dosewise_test           # or a Neon test branch
DATABASE_URL=... DIRECT_URL=... npx prisma migrate deploy
# ensure prisma/sql/0001_appointment_no_overlap.sql is part of the init migration
npx vitest run tests/double-booking.constraint.test.ts
```

Never point these at a non-test database. `prisma migrate reset` / `db push
--force-reset` are for local/dev only.
