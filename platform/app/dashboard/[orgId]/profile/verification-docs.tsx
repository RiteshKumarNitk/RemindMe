"use client";

import { useRef, useState } from "react";
import { Button } from "@/components/ui/index.js";

const ACCEPT = ".pdf,.jpg,.jpeg,.png,.webp";
const MAX_MB = 10;

/**
 * Upload control for verification evidence. Posts multipart directly to the
 * API route (not a server action) so the browser streams the file once and
 * the route's explicit error envelope drives the message shown here.
 */
export function VerificationDocUpload({ orgId }: { orgId: string }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: "ok" | "down"; text: string } | null>(null);

  async function submit() {
    const file = inputRef.current?.files?.[0];
    if (!file) {
      setMessage({ tone: "down", text: "Choose a file first." });
      return;
    }
    if (file.size > MAX_MB * 1024 * 1024) {
      setMessage({ tone: "down", text: `Files must be ${MAX_MB} MB or smaller.` });
      return;
    }
    setBusy(true);
    setMessage(null);
    try {
      const body = new FormData();
      body.set("file", file);
      const res = await fetch(`/api/orgs/${orgId}/verification-documents`, { method: "POST", body });
      const json = (await res.json().catch(() => null)) as { error?: { message?: string } } | null;
      if (!res.ok) {
        setMessage({ tone: "down", text: json?.error?.message ?? "Upload failed — try again." });
      } else {
        setMessage({ tone: "ok", text: "Uploaded." });
        if (inputRef.current) inputRef.current.value = "";
        // Re-render the server component list with the new row.
        location.reload();
      }
    } catch {
      setMessage({ tone: "down", text: "Upload failed — check your connection and try again." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-3">
      <div className="flex flex-wrap items-center gap-2">
        <input
          ref={inputRef}
          type="file"
          accept={ACCEPT}
          className="max-w-xs text-sm text-ink-muted file:mr-3 file:cursor-pointer file:rounded-control file:border-0 file:bg-surface-2 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-ink"
          aria-label="Verification document"
        />
        <Button type="button" variant="secondary" size="sm" onClick={submit} disabled={busy}>
          {busy ? "Uploading…" : "Upload"}
        </Button>
      </div>
      <p className="mt-1.5 text-[11.5px] text-ink-faint">
        PDF, JPEG, PNG or WebP · up to {MAX_MB} MB · visible only to your clinic and the DoseWise
        review team.
      </p>
      {message ? (
        <p
          role="status"
          className={`mt-1.5 text-[12.5px] font-medium ${message.tone === "ok" ? "text-ok" : "text-down"}`}
        >
          {message.text}
        </p>
      ) : null}
    </div>
  );
}
