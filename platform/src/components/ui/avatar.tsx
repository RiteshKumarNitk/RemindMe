const GRADIENTS = [
  "from-indigo to-[#8b85f5]",
  "from-coral to-[#f7a1a1]",
  "from-ok to-[#6ee7a0]",
  "from-warn to-[#fbbf6b]",
];

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
 * (queue, "up next," family lists) without a real photo. */
export function InitialsAvatar({ name, className = "" }: { name: string; className?: string }) {
  const gradient = GRADIENTS[hash(name) % GRADIENTS.length];
  return (
    <div
      className={`flex h-8.5 w-8.5 shrink-0 items-center justify-center rounded-control bg-linear-to-br font-display text-xs font-bold text-white ${gradient} ${className}`}
    >
      {initials(name)}
    </div>
  );
}
