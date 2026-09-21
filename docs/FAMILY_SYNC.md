# Family sync — QR invitations & multi-member households

## Model

```
households/{id}                     { createdAt, ownerUid }
households/{id}/members/{uid}        { userId, householdId, name, role,
                                       permissions{shareMedicines,
                                       shareMissedAlerts}, createdAt, fcmToken? }
households/{id}/medicines/{id}       medicine snapshot   (members-only)
households/{id}/doses/{medId_ts}     dose snapshot       (members-only)
invitations/{sha256(token)}         { householdId, creatorUid, creatorName,
                                       createdAt, expiresAt, used, usedBy, usedAt }
```

- **One `owner`** per household (its creator). Everyone else is a `member`.
  These are the only two roles. Legacy strings (`primary`, `watcher`,
  `admin`) are normalised on read by `FamilyRole.normalize`.
- **Multi-member** by construction: `members` is a subcollection, not a
  two-party link. A → B → C → D all get their own record.
- The household **id is not a secret**. It is an opaque short handle used as
  a document key and a human-shareable string. Security is: members-only
  reads (rules), owner-only removal (rules), and join-only-by-invitation.

## QR invitation flow

**Show My QR** (`FamilyQrShowScreen`)
1. `InvitationService.createInvitation(householdId, creatorUid, creatorName)`
2. 256-bit `Random.secure()` token → stored at `invitations/{sha256(token)}`
   with `used:false`, `expiresAt: now + 24h`.
3. QR payload = `{"type":"dosewise_invite","token":<raw>,"v":1}` — **token
   only**. No household id, uid, email, name, or medical data. (Verified by
   `test/family_invitation_test.dart`.)

**Scan Family QR** (`FamilyQrScanScreen` → `FamilyConnectionConfirmScreen`)
1. Parse payload; reject non-DoseWise / empty.
2. `validateInvitation(token, currentUid)` — exists, not expired, not used,
   not your own token, not already a member.
3. Show **Family Connection Request** with **Cancel** / **Connect**.
4. **Connect** → `acceptInvitation(token, currentUid, currentUserName)`:
   a single **Firestore transaction** that
   - re-checks unused / unexpired / not-self / not-already-member,
   - flips the invitation to `used:true, usedBy, usedAt`,
   - writes `members/{uid}` with `role:'member'`, default-private
     `permissions`, `createdAt`, and `inviteHash` (ties the record to the
     consumed token).
   Atomic ⇒ a double-scan or two devices racing the same QR can't create a
   duplicate membership or a half-applied join.
5. `SyncService.enableSync(role:'member', joinCode: householdId)` points the
   local sync at the household (`FirebaseBackend.joinHousehold` now only
   *verifies* the membership record exists — it no longer writes one).

**Create Family** (`_enable(FamilyRole.owner)` → `FirebaseBackend.createHousehold`)
- Collision-safe: a transaction that writes only if the id is free, retried
  with a fresh id on clash. **Never a bare `set()`** (the old bug — could
  silently overwrite another household).
- Writes the household doc **and** the owner's `members/{uid}` record
  (`role:'owner'`) in the same transaction.

## Firestore rules (`firestore.rules`)

| Path | read | create | update | delete |
|------|------|--------|--------|--------|
| `households/{id}` | members only | signed-in, `ownerUid == uid` | never | never |
| `.../members/{uid}` | members only | self only: `role:'member'` **iff** the `inviteHash` invitation was consumed by you for this household in the same commit (`getAfter`), **or** `role:'owner'` iff you are the household's `ownerUid` | self only, role unchanged (no self-promotion) | self-leave (non-owner), or owner removing a non-owner |
| `.../medicines`, `.../doses` | members only | members only | members only | members only |
| `invitations/{hash}` | `get` only (no `list`) | creator, `used:false` | consume once: `used` false→true, `usedBy == uid`, household/creator unchanged | creator only |

Consequences:
- **No membership without a consumed invitation** — a tampered client
  cannot write itself into `members` (the `getAfter` invitation check fails).
- **Access revoked on removal** — deleting `members/{uid}` makes every
  subsequent `medicines`/`doses` request fail `isMember`.
- **Self-invite blocked** in both the client (`validateInvitation` /
  `acceptInvitation`) and implicitly (you'd need someone else's token).
- **Unauthorized removal blocked** — only the owner can delete another
  member's record; the owner's own record can never be deleted.

## Privacy

`permissions` defaults to `{shareMedicines:false, shareMissedAlerts:false}`.
Joining a family exposes **nothing** of a member's medication data until
they opt in (`InvitationService.updateMyPermissions`). The rules guarantee
non-members see nothing at all; the caregiver dashboard is expected to
honour `shareMedicines` for what it surfaces between members.

## ⚠️ Must be verified by a human (needs a Firebase project)

This layer has **no automated coverage** beyond the pure helpers
(`FamilyRole`, `FamilyPermissions`, QR payload) — Firestore transactions
and rules can only be exercised against the emulator or a real project.

1. `firebase deploy --only firestore:rules`
2. With the **Firestore emulator + `@firebase/rules-unit-testing`**, assert:
   - a non-member cannot read `households/{id}` or any medicine/dose;
   - a client cannot create `members/{uid}` without consuming an invitation;
   - a second `acceptInvitation` with the same token fails;
   - a member cannot change their own `role`;
   - a non-owner cannot delete another member; the owner can; the owner
     cannot be deleted;
   - after removal, the ex-member's next `pullMedicines` gets
     `permission-denied`.
3. End-to-end on two devices: A creates → A shows QR → B scans → B sees the
   confirm screen → Connect → both appear in **My Family**; add a third
   device C the same way; A removes C; C's sync starts failing.
