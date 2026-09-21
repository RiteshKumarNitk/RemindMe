import type { ElementType, HTMLAttributes } from "react";

export function Card({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-card border border-border bg-card p-5 ${className}`}
      {...rest}
    />
  );
}

export function CardTitle({
  as: Tag = "h3",
  className = "",
  ...rest
}: HTMLAttributes<HTMLHeadingElement> & { as?: ElementType }) {
  return <Tag className={`text-base font-semibold text-ink ${className}`} {...rest} />;
}

export function CardSubtitle({ className = "", ...rest }: HTMLAttributes<HTMLParagraphElement>) {
  return <p className={`text-sm text-ink-muted ${className}`} {...rest} />;
}
