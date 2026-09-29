"use client";

import type { ReactNode } from "react";
import { Button } from "@/components/ui/index.js";

/**
 * A submit button that asks for confirmation first.
 *
 * Wraps destructive server-action forms (Cancel appointment, Remove member,
 * Sign & complete a consultation) which previously fired immediately on click
 * — one stray tap on a phone was enough to cancel a real appointment or lock
 * a clinical record. Uses the native `confirm()` dialog on purpose: it blocks
 * submission before any network traffic, works without focus management or
 * portal code, and is announced by screen readers out of the box.
 */
export function ConfirmSubmit({
  label,
  confirmTitle,
  confirmMessage,
  variant = "primary",
  size = "md",
  formAction,
}: {
  label: ReactNode;
  confirmTitle: string;
  confirmMessage: string;
  variant?: "primary" | "secondary" | "ghost" | "danger";
  size?: "sm" | "md" | "lg";
  /** Optional bound server action — lets a confirm-guarded button post to a
   * different action than its surrounding <form> (e.g. a Deactivate button
   * living inside a location's Save form). Omitted = submit the form's own
   * action, as before. */
  formAction?: (formData: FormData) => void | Promise<void>;
}) {
  return (
    <Button
      type="submit"
      variant={variant}
      size={size}
      {...(formAction ? { formAction } : {})}
      onClick={(e) => {
        if (!window.confirm(`${confirmTitle}\n\n${confirmMessage}`)) {
          e.preventDefault();
        }
      }}
    >
      {label}
    </Button>
  );
}
