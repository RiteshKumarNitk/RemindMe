import Link, { type LinkProps } from "next/link";
import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
type ButtonSize = "sm" | "md" | "lg";

const VARIANT_CLASSES: Record<ButtonVariant, string> = {
  primary: "bg-indigo text-white hover:bg-indigo-dark",
  secondary: "bg-card text-ink border border-border hover:bg-surface",
  ghost: "bg-transparent text-ink hover:bg-surface",
  danger: "bg-down text-white hover:opacity-90",
};

const SIZE_CLASSES: Record<ButtonSize, string> = {
  sm: "h-8 px-3 text-sm",
  md: "h-10 px-4 text-sm",
  lg: "h-12 px-6 text-base",
};

function buttonClasses(variant: ButtonVariant, size: ButtonSize, className: string): string {
  return `inline-flex items-center justify-center gap-2 rounded-control font-medium no-underline transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${VARIANT_CLASSES[variant]} ${SIZE_CLASSES[size]} ${className}`;
}

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  children: ReactNode;
}

export function Button({
  variant = "primary",
  size = "md",
  className = "",
  children,
  ...rest
}: ButtonProps) {
  return (
    <button className={buttonClasses(variant, size, className)} {...rest}>
      {children}
    </button>
  );
}

export interface LinkButtonProps
  extends LinkProps,
    Omit<AnchorHTMLAttributes<HTMLAnchorElement>, keyof LinkProps> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  children: ReactNode;
}

/**
 * A navigation link styled identically to `Button`. Use this instead of wrapping
 * a `<Button>` in a `<Link>` — nesting a real `<button>` inside an `<a>` is invalid
 * HTML and gives keyboard/screen-reader users two confusing, overlapping tab stops
 * for what is really one navigation action.
 */
export function LinkButton({
  variant = "primary",
  size = "md",
  className = "",
  children,
  ...rest
}: LinkButtonProps) {
  return (
    <Link className={buttonClasses(variant, size, className)} {...rest}>
      {children}
    </Link>
  );
}
