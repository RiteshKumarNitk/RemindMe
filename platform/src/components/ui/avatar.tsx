const GRADIENTS = [
  "from-indigo to-[#8b85f5]",
  "from-coral to-[#f7a1a1]",
  "from-ok to-[#6ee7a0]",
  "from-warn to-[#fbbf6b]",
];

const SIZES = {
  sm: "h-8.5 w-8.5 text-xs",
  md: "h-12 w-12 text-sm",
  lg: "h-16 w-16 text-lg",
} as const;

function hash(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) h = (h * 31 + input.charCodeAt(i)) >>> 0;
  return h;
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  return ((parts[0]?.[0] ?? "") + (parts[1]?.[0] ?? "")).toUpperCase() || "?";
}

/** A colored-initials avatar, deterministic per name (same person always gets
 * the same color) — used anywhere a list needs a quick visual anchor per row
 * (queue, "up next," family lists) without a real photo. `lg` suits discovery
 * cards and profile headers; `sm` (default) suits dense list rows. */
export function InitialsAvatar({
  name,
  size = "sm",
  className = "",
}: {
  name: string;
  size?: keyof typeof SIZES;
  className?: string;
}) {
  const gradient = GRADIENTS[hash(name) % GRADIENTS.length];
  return (
    <div
      className={`flex shrink-0 items-center justify-center rounded-control bg-linear-to-br font-display font-bold text-white ${SIZES[size]} ${gradient} ${className}`}
    >
      {initials(name)}
    </div>
  );
}
