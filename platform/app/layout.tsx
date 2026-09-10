import type { ReactNode } from "react";

export const metadata = {
  title: "DoseWise Platform",
  description: "Multi-tenant healthcare appointment & patient management API",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
