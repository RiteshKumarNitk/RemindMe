/**
 * Typed application errors → a uniform JSON envelope. Raw DB / framework
 * errors are never surfaced (SECURITY.md "Error handling").
 */
export type ErrorCode =
  | "MALFORMED_REQUEST"
  | "VALIDATION_FAILED"
  | "NOT_AUTHENTICATED"
  | "TOKEN_EXPIRED"
  | "REFRESH_REUSE_DETECTED"
  | "INVALID_CREDENTIALS"
  | "EMAIL_TAKEN"
  | "FORBIDDEN_ROLE"
  | "FORBIDDEN"
  | "CANNOT_SELF_GRANT_CAPABILITY"
  | "OUTSIDE_CANCELLATION_WINDOW"
  | "NOT_FOUND"
  | "CONFLICT"
  | "APPOINTMENT_SLOT_TAKEN"
  | "INVALID_STATUS_TRANSITION"
  | "TOKEN_ALREADY_USED"
  | "RATE_LIMITED"
  | "NOT_IMPLEMENTED"
  | "INTERNAL";

const STATUS: Record<ErrorCode, number> = {
  MALFORMED_REQUEST: 400,
  VALIDATION_FAILED: 422,
  NOT_AUTHENTICATED: 401,
  TOKEN_EXPIRED: 401,
  REFRESH_REUSE_DETECTED: 401,
  INVALID_CREDENTIALS: 401,
  EMAIL_TAKEN: 409,
  FORBIDDEN_ROLE: 403,
  FORBIDDEN: 403,
  CANNOT_SELF_GRANT_CAPABILITY: 403,
  OUTSIDE_CANCELLATION_WINDOW: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  APPOINTMENT_SLOT_TAKEN: 409,
  INVALID_STATUS_TRANSITION: 409,
  TOKEN_ALREADY_USED: 409,
  RATE_LIMITED: 429,
  NOT_IMPLEMENTED: 501,
  INTERNAL: 500,
};

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details?: unknown;

  constructor(code: ErrorCode, message: string, details?: unknown) {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.status = STATUS[code];
    this.details = details;
  }
}

export const notFound = (msg = "Not found.") => new AppError("NOT_FOUND", msg);
export const forbidden = (msg = "You do not have access to this resource.") =>
  new AppError("FORBIDDEN", msg);
export const unauthorized = (msg = "Authentication required.") =>
  new AppError("NOT_AUTHENTICATED", msg);
export const conflict = (msg: string) => new AppError("CONFLICT", msg);

export interface ErrorEnvelope {
  error: { code: ErrorCode; message: string; details?: unknown };
}

export function toEnvelope(err: AppError): ErrorEnvelope {
  return {
    error: {
      code: err.code,
      message: err.message,
      ...(err.details !== undefined ? { details: err.details } : {}),
    },
  };
}
