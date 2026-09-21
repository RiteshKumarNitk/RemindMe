import type { ReactNode } from "react";
import { IBM_Plex_Mono, IBM_Plex_Sans, Sora } from "next/font/google";
import "./globals.css";

// Self-hosted via next/font (no external <link>, no layout shift). Scoped to
// CSS variables, not applied to <body> directly — every existing page keeps
// its current system-font stack; only the new dashboard shell/cards opt in
// via the `font-display`/`font-dash-mono` utilities these variables back.
const sora = Sora({ subsets: ["latin"], weight: ["600", "700", "800"], variable: "--nf-sora" });
const plexSans = IBM_Plex_Sans({ subsets: ["latin"], weight: ["400", "500", "600"], variable: "--nf-plex-sans" });
const plexMono = IBM_Plex_Mono({ subsets: ["latin"], weight: ["400", "500"], variable: "--nf-plex-mono" });

export const metadata = {
  title: "DoseWise Platform",
  description: "Multi-tenant healthcare appointment & patient management API",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${sora.variable} ${plexSans.variable} ${plexMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
