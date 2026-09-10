# Medicine Data Migration — DoseWise → PostgreSQL

Field-by-field mapping from the **actual** DoseWise structures (SQLite v8 +
Firestore household docs + SharedPreferences) to the Prisma models. Nothing is
migrated in Phase 0; this is the spec the importer will follow.

## Sources

| Source | Location | Notes |
|---|---|---|
| SQLite v8 | on-device `medireminder.db` | authoritative for one device |
| Firestore | `households/{code}/medicines`, `.../doses` | the family's merged view (LWW on `updated_at`) |
| Backup JSON | `dosewise_backup_<ts>.json` | medicines + **all** SharedPreferences (only cloud-free source of **vitals**) |
| Export JSON | `ExportService.exportToJson()` | medicines + 365-day doses; also a supported importer input |

Preferred order when several exist: **Firestore** (merged, newest) → device
SQLite → backup/export JSON. All merges are last-writer-wins on the
`updated_at` / `updatedAt` field, matching the app's own model.

## Identity & idempotency

DoseWise ids are **per-device autoincrement integers**. To import safely and
repeatably:

- `Medication.legacyLocalId` = the DoseWise `medicines.id`
- `Medication.sourceDeviceId` = a stable device/install id (from the client
  during migration; `"firestore:<householdCode>"` when importing from the
  cloud)
- `@@unique([sourceDeviceId, legacyLocalId])` makes re-running the import a
  no-op.
- Dose identity is `@@unique([medicationId, scheduledAtLocal])` — the same
  natural key the app already uses (`(medicine_id, scheduled_at)`).

Every imported row gets `source = "dosewise-import"`.

## `medicines` → `Medication`

| DoseWise column | Type | → Prisma field | Transform |
|---|---|---|---|
| `id` | INTEGER | `legacyLocalId` | copy; new `id` is a UUID |
| `name` | TEXT | `name` | trim |
| `dosage` | TEXT (`''`) | `dosage` | copy |
| `dosage_unit` | TEXT (`''`) | `dosageUnit` | copy |
| `notes` | TEXT (`''`) | `notes` | copy |
| `food_instruction` | TEXT enum name | `foodInstruction` | `none→NONE`, `before→BEFORE`, `after→AFTER`, `withFood→WITH_FOOD` |
| `frequency` | TEXT enum name | `frequency` | `daily→DAILY`, `specificDays→SPECIFIC_DAYS`, `once→ONCE`, `multiple→MULTIPLE` |
| `selected_days` | TEXT CSV of ints | `selectedDays Int[]` | split `,` → `int[]`; keep ISO 1..7 (DoseWise already uses `DateTime.monday..sunday`) |
| `once_date` | TEXT `yyyy-MM-dd` | `onceDate @db.Date` | parse date |
| `active` | INTEGER 0/1 | `isActive` | `== 1` |
| `stock_count` | INTEGER? | `stockCount` | copy (nullable) |
| `refill_at` | INTEGER? | `refillAt` | copy (nullable) |
| `created_at` | TEXT ISO | `createdAt` | parse |
| `updated_at` | TEXT ISO | `updatedAt` | parse (drives LWW) |
| — | | `organizationId` | the target clinic tenant for this patient |
| — | | `patientId` | the migrated self `Patient` (or the dependent) |
| — | | `ownerUserId` | the managing `User` (gates clinic visibility) |
| — | | `source` | `"dosewise-import"` |
| tombstone (`sync_tombstones` / Firestore `deleted:true`) | | `deletedAt` | set to the tombstone's `updated_at` |

## `medicine_schedules` → `MedicationSchedule`

| DoseWise | → | Transform |
|---|---|---|
| `id` | (dropped; new UUID) | |
| `medicine_id` | `medicationId` | resolve via `(sourceDeviceId, legacyLocalId)` |
| `hour` | `hour` | copy |
| `minute` | `minute` | copy |
| `enabled` | `enabled` | `== 1` |

Schedules are replaced wholesale per medication (same as the app).

## `medicine_doses` → `MedicationDose`

| DoseWise column | → Prisma field | Transform |
|---|---|---|
| `id` | (dropped; new UUID) | never reuse the autoincrement id |
| `medicine_id` | `medicationId` | resolve via legacy key |
| `scheduled_at` | `scheduledAtLocal` | **kept as naive local wall-clock** — do NOT convert to UTC |
| — | `timezone` | the device/clinic IANA zone at import (best available; default `Asia/Kolkata`, flag for review) |
| `status` | `status` | `pending→PENDING`, `taken→TAKEN`, `skipped→SKIPPED`, `missed→MISSED` |
| `taken_at` | `takenAt @db.Timestamptz` | parse (real instant) |
| `skipped_at` | `skippedAt @db.Timestamptz` | parse |
| `snoozed_until` | `snoozedUntil` | parse |
| `created_at` | `createdAt` | parse |
| `updated_at` | `updatedAt` | parse (LWW) |
| `sync_dose_tombstones` row / Firestore `deleted:true` | `deletedAt` | tombstone `updated_at` |
| — | `organizationId`, `patientId` | denormalized from the parent medication |

**Retention:** import doses from the last 365 days by default (matches the
export window); older history optional and configurable.

## Firestore household docs → family / access

| Firestore | → Prisma | Notes |
|---|---|---|
| `households/{code}` | (no direct table) | becomes the grouping key for a set of `FamilyRelationship` rows |
| `.../members/{uid}` `role` | — | `owner`/`member` do not map to clinic roles; used only to decide who is the managing `User` |
| `.../members/{uid}` `permissions.shareMedicines` | `PatientAccessGrant.permissions += VIEW_MEDICATIONS` | only if `true` |
| `.../members/{uid}` `permissions.shareMissedAlerts` | notification preference on the grantee | not a schema field in MVP |
| `.../members/{uid}` `fcmToken` | `POST /api/me/devices` (re-registered by the client) | never imported into audit |
| `invitations/*` | not migrated | short TTL; regenerate as platform `Invitation`s |

Default-private posture is preserved: **no** grant is created unless the source
`permissions` flag was explicitly `true`.

## SharedPreferences → misc

| Pref key | → | Notes |
|---|---|---|
| `user_name` | `User.fullName` | |
| `user_age` | transitional; capture `dateOfBirth` on the self `Patient` going forward | age alone is not stored |
| `locale` | `User.locale` | |
| `vital_<id>` (`List<String>` = `[id, type, value, value2, recordedAt, notes]`) | `VitalReading` | `type`: `bloodPressure→BLOOD_PRESSURE`, `bloodSugar→BLOOD_SUGAR`, `weight→WEIGHT`, `temperature→TEMPERATURE`, `heartRate→HEART_RATE`; `value2` = diastolic |
| notification/device prefs (`sound_enabled`, `snooze_minutes`, …) | not migrated | stay device-local |
| `household_code`, `sync_role`, `last_sync_at` | not migrated | replaced by platform sync state |

## Importer behaviour

- Runs as an authenticated call from the Flutter client (it holds the device
  data) **or** as a server-side script against an uploaded Firestore export.
- Idempotent (`sourceDeviceId` + legacy keys); safe to re-run.
- Wrapped per-patient in a transaction; a bad row is skipped and reported, not
  fatal (mirrors the app's own resilient sync).
- Emits `AuditLog` (`action = "MEDICATION_IMPORTED"`, counts in `metadata`).
- Never deletes local data; the device SQLite remains the offline store.

## Open items (flag for review)

- **Timezone for historical doses**: no per-dose tz exists in DoseWise. Default
  assumption `Asia/Kolkata` (Firebase project + Hindi locale suggest India);
  confirm or make it a migration parameter.
- **Which clinic** a migrating self-managing patient lands in (they may not
  belong to any clinic yet — a "personal" org, or a null-org patient space?).
  Needs a product decision before the importer ships.
