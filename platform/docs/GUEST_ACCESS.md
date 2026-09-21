# Guest Access

Two unrelated things are called "guest". This document defines both and the
hard boundary around the platform one.

---

## 1. Platform guest mode (new) — demo / preview only

### Purpose

Let a prospective clinic or a reviewer **click through the product** — see the
dashboards, the booking flow, the queue board — **without creating an account
and without touching any real data**. That is the entire purpose. It is a sales
/ evaluation aid, not a usage tier.

### How it works

- A single **demo organization** (`slug = "demo"`, `isActive = true`, flagged
  `isDemo = true`) is seeded once and owned by the platform. It contains only
  clearly-labelled synthetic patients, doctors, appointments, and medications.
  No real person's data is ever in it.
- `POST /api/auth/guest` mints a **guest session**: a real (ephemeral) `User`
  with `isGuest = true` and one **`Membership` in the demo org with role
  `PATIENT`** (nothing more).
- The guest goes through the **exact same pipeline** as everyone else:
  authenticate → resolve tenant (`:orgId` must be the demo org) → RBAC →
  service ownership checks. Nothing is special-cased to skip a check.

#### The walkthrough (DOCTOR / RECEPTION dashboards)

To let a prospect *see* the doctor and reception screens, there is **no extra
capability and no bypass**. It is a single, narrow, **demo-only policy rule**
evaluated by `can()` **after** every standard check has already passed:

```
allowDemoWalkthrough(ctx, action, resource) :=
      ctx.user.isGuest === true
  AND ctx.organizationId === DEMO_ORG_ID          // tenant already resolved
  AND action is a READ (never a write)
  AND resource is one of an allow-listed set of demo dashboard reads
```

Properties:

- It is **additive-allow only for reads** on the demo org. It cannot grant a
  write, cannot widen tenant scope (the tenant is already pinned to the demo
  org by path resolution), and cannot touch another user's data — service
  ownership checks still run and the data is 100% synthetic.
- It lives in the policy module (`src/lib/rbac.ts`) as an explicit branch, not
  as a `MembershipCapability` value and not as a role. The
  `MembershipCapability` enum is unchanged (`CLINICAL_RECORD_READ`,
  `CLINICAL_RECORD_WRITE`, `BILLING_MANAGE`, `DATA_EXPORT` only).
- It is a no-op for every non-guest user and for every org that is not the demo
  org, so it cannot affect a real tenant even if mis-scoped.
- If the walkthrough is deemed unnecessary, delete the branch — guests are
  then plain demo-org `PATIENT`s.

### Hard limits (all enforced server-side)

A guest principal **cannot**:

- read or write data in **any organization except the demo org** — tenant
  resolution returns `404` for every other `:orgId`, exactly as for any user
  without that membership;
- read or write **another user's** data (same object-level checks as everyone);
- read **real clinical data** — there is none in the demo org, and the guest
  has no membership anywhere else;
- **bypass tenant isolation or RBAC** — a guest is not exempt from a single
  rule in [MULTI_TENANCY.md](MULTI_TENANCY.md) or [RBAC.md](RBAC.md);
- create **production appointments** — writes in the demo org are allowed only
  against demo doctors/patients, are marked `bookingSource = ADMIN` +
  `isDemoData = true`, and are **purged on a schedule**;
- obtain a **long-lived credential** — a guest session gets a short access
  token and **no refresh token** (or a single short one, non-rotating); it
  simply expires;
- be promoted — there is no path from `isGuest` to a real membership; the user
  registers normally instead.

### Operational

- Guest sessions are **rate-limited** more tightly than normal auth
  (`POST /api/auth/guest` shares the `/api/auth/*` budget) to prevent demo-org
  spam.
- Demo-org writes are swept by the same periodic job that drains notifications
  (`isDemoData = true AND createdAt < now - 24h` → delete).
- Guest activity is still audited (`actorRole = PATIENT`, `organizationId =
  demo`), so abuse is visible.
- Guest mode can be disabled entirely with one env flag if it is ever abused.

### Schema note

Not added to `schema.prisma` in this pass to avoid pre-committing detail before
Phase 1. The minimal additions when it is built: `User.isGuest Boolean
@default(false)`, `Organization.isDemo Boolean @default(false)`, and an
`isDemoData Boolean @default(false)` flag on the handful of demo-writable
models (`Appointment`, `Patient`, `Medication`). Flagged here so it is a
deliberate decision, not a silent one.

---

## 2. DoseWise "guest" (existing) — offline, no account

### What it is today

In the current Flutter app, `LoginScreen(onSkip:)` lets the user **skip
sign-in entirely**. The app is then fully functional **offline**: local SQLite
+ SharedPreferences only. `profile_screen.dart` shows "Guest User"
(`profileGuestUser`) when `user_name` is empty. There is **no server, no
Firebase, no data leaving the device** in this state — cloud sync (Firebase
anonymous auth + Firestore) is only engaged if the user explicitly enables
Family Sync.

### It is NOT the same as platform guest mode

| | DoseWise "guest" | Platform guest mode |
|---|---|---|
| Backend involvement | none (fully local) | a real ephemeral session against the demo org |
| Data | the user's own real medication data, on-device | synthetic demo data only |
| Purpose | use the app without an account | evaluate the platform without an account |
| Network | offline | online, sandboxed |

### Mapping to the new auth system — DECISION DEFERRED

How a DoseWise offline "guest" user becomes a platform user is an **open
decision** (see [ROADMAP.md](ROADMAP.md) Phase 5 and the "requires a decision"
list in the Phase 0 report). Candidate options, not yet chosen:

1. **Stay offline-only** — a DoseWise guest never becomes a platform account;
   they must register (Google or email) to sync or use clinic features. Local
   data is untouched and importable later.
2. **Local-account shim** — the app keeps working offline; on first sign-in,
   the local medication data is imported to the new `User`'s self `Patient`
   via the documented importer ([MEDICINE_DATA_MIGRATION.md](MEDICINE_DATA_MIGRATION.md)).

Option 1 is the current assumption in the docs. Nothing is implemented either
way in Phase 0.
