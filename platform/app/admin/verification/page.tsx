import Link from "next/link";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { listOrganizations } from "@/modules/superadmin/service.js";
import { Badge, Card, EmptyState, SectionTitle, Table, td, th } from "../../dashboard/ui.js";

export const dynamic = "force-dynamic";

export default async function AdminVerificationQueuePage() {
  const ctx = await requireSuperAdmin();
  const { data: orgs } = await listOrganizations(ctx, {
    status: "all",
    verification: "pending",
    limit: 100,
  });

  return (
    <div>
      <SectionTitle>Verification queue ({orgs.length})</SectionTitle>
      <p style={{ color: "var(--ink-muted)", fontSize: 14, marginBottom: 16 }}>
        Clinics that have asked to be reviewed for a &ldquo;Verified&rdquo; badge on their public
        profile.
      </p>
      <Card>
        {orgs.length === 0 ? (
          <EmptyState>Nothing awaiting review.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>Slug</th>
                <th style={th}>Listed publicly</th>
                <th style={th}>Members</th>
                <th style={th}>
                  <span className="sr-only">Review</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {orgs.map((o) => (
                <tr key={o.id}>
                  <td style={td}>{o.name}</td>
                  <td style={td}>{o.slug}</td>
                  <td style={td}>
                    <Badge tone={o.isPubliclyListed ? "ok" : "muted"}>{o.isPubliclyListed ? "Yes" : "No"}</Badge>
                  </td>
                  <td style={td}>{o._count.memberships}</td>
                  <td style={td}>
                    <Link href={`/admin/organizations/${o.id}`} style={{ color: "var(--indigo)", fontWeight: 700, fontSize: 13 }}>
                      Review
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
    </div>
  );
}
