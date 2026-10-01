import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import type { RequestContext } from "@/lib/context.js";

/**
 * Verification evidence documents (request: "super-admins can review evidence
 * before granting VERIFIED"). A clinic's CLINIC_ADMIN uploads license /
 * registration files alongside (or before) `requestVerification`; the platform
 * reviewer sees and downloads them on the admin org-detail page.
 *
 * Storage: the bytes live in the `VerificationDocument` table — this codebase
 * deliberately runs on plain Postgres with no external object storage, and the
 * access pattern (a handful of small files per clinic, admin-only downloads)
 * fits. 10 MB / file, PDF or image, max 10 per clinic.
 */

const MAX_SIZE_BYTES = 10 * 1024 * 1024;
const MAX_DOCUMENTS_PER_ORG = 10;

const ALLOWED_MIME = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
]);

export interface UploadedVerificationDoc {
  id: string;
  fileName: string;
  mimeType: string;
  sizeBytes: number;
  createdAt: Date;
}

function assertClinicAdmin(ctx: RequestContext): void {
  if (ctx.org?.role !== "CLINIC_ADMIN") {
    throw new AppError("FORBIDDEN_ROLE", "Only a clinic admin can manage verification documents.");
  }
}

export async function uploadVerificationDocument(
  ctx: RequestContext,
  file: File,
): Promise<UploadedVerificationDoc> {
  assertClinicAdmin(ctx);
  const orgId = ctx.org!.id;

  if (!(file instanceof File) || file.size === 0) {
    throw new AppError("VALIDATION_FAILED", "Choose a file to upload.");
  }
  if (file.size > MAX_SIZE_BYTES) {
    throw new AppError("VALIDATION_FAILED", "Files must be 10 MB or smaller.");
  }
  const mime = file.type || "application/octet-stream";
  if (!ALLOWED_MIME.has(mime)) {
    throw new AppError("VALIDATION_FAILED", "Only PDF, JPEG, PNG or WebP files are accepted.");
  }

  const existingCount = await db.verificationDocument.count({ where: { organizationId: orgId } });
  if (existingCount >= MAX_DOCUMENTS_PER_ORG) {
    throw new AppError("CONFLICT", `At most ${MAX_DOCUMENTS_PER_ORG} documents per clinic — remove one first.`);
  }

  const data = new Uint8Array(await file.arrayBuffer());
  const created = await db.verificationDocument.create({
    data: {
      organizationId: orgId,
      fileName: file.name.slice(0, 200),
      mimeType: mime,
      sizeBytes: file.size,
      data,
      uploadedById: ctx.userId,
    },
    select: { id: true, fileName: true, mimeType: true, sizeBytes: true, createdAt: true },
  });

  await writeAudit(ctx, {
    action: "VERIFICATION_DOCUMENT_UPLOADED",
    entityType: "VerificationDocument",
    entityId: created.id,
    after: { fileName: created.fileName, sizeBytes: created.sizeBytes },
  });
  return created;
}

export async function deleteVerificationDocument(ctx: RequestContext, documentId: string): Promise<void> {
  assertClinicAdmin(ctx);
  const doc = await db.verificationDocument.findFirst({
    where: { id: documentId, organizationId: ctx.org!.id },
    select: { id: true, fileName: true },
  });
  if (!doc) throw new AppError("NOT_FOUND", "Not found.");

  await db.verificationDocument.delete({ where: { id: doc.id } });
  await writeAudit(ctx, {
    action: "VERIFICATION_DOCUMENT_DELETED",
    entityType: "VerificationDocument",
    entityId: doc.id,
    before: { fileName: doc.fileName },
  });
}

/** Metadata list for the clinic's own profile page (no bytes). */
export async function listMyVerificationDocuments(ctx: RequestContext) {
  assertClinicAdmin(ctx);
  const rows = await db.verificationDocument.findMany({
    where: { organizationId: ctx.org!.id },
    orderBy: { createdAt: "desc" },
    select: { id: true, fileName: true, mimeType: true, sizeBytes: true, createdAt: true },
  });
  return rows;
}

/**
 * The bytes themselves. Two legitimate audiences, checked explicitly:
 * the clinic's own CLINIC_ADMIN, and any platform admin (verification
 * reviewers). Everyone else — including other clinics — gets the same 404
 * a missing document returns.
 */
export async function getVerificationDocumentBytes(
  ctx: RequestContext,
  organizationId: string,
  documentId: string,
): Promise<{ fileName: string; mimeType: string; data: Uint8Array }> {
  if (ctx.isPlatformAdmin) {
    // Platform reviewers are unscoped by design (superadmin module pattern).
  } else if (ctx.org?.role === "CLINIC_ADMIN" && ctx.org.id === organizationId) {
    // The owning clinic.
  } else {
    throw new AppError("NOT_FOUND", "Not found.");
  }

  const doc = await db.verificationDocument.findFirst({
    where: { id: documentId, organizationId },
    select: { fileName: true, mimeType: true, data: true },
  });
  if (!doc) throw new AppError("NOT_FOUND", "Not found.");
  return { fileName: doc.fileName, mimeType: doc.mimeType, data: doc.data };
}

/** Metadata list for the platform reviewer (no bytes). */
export async function listVerificationDocumentsForReview(
  ctx: RequestContext,
  organizationId: string,
) {
  if (!ctx.isPlatformAdmin) {
    throw new AppError("FORBIDDEN_ROLE", "Platform admin only.");
  }
  return db.verificationDocument.findMany({
    where: { organizationId },
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      fileName: true,
      mimeType: true,
      sizeBytes: true,
      createdAt: true,
      uploadedBy: { select: { fullName: true, email: true } },
    },
  });
}
