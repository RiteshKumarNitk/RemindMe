import { requireWebUser } from "@/lib/web-context.js";
import { Button, Card, ErrorNote, Field } from "../ui.js";
import { createOrgAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function NewClinicPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  await requireWebUser();
  const { error } = await searchParams;

  return (
    <main style={{ maxWidth: 460, margin: "64px auto", padding: "0 20px" }}>
      <h1 style={{ fontSize: 22, margin: "0 0 18px" }}>Create a clinic</h1>
      <Card>
        <ErrorNote message={error} />
        <form action={createOrgAction}>
          <Field label="Clinic name" name="name" required placeholder="Sunrise Family Clinic" />
          <Field label="URL slug" name="slug" required placeholder="sunrise-clinic" />
          <Field label="Timezone" name="timezone" defaultValue="Asia/Kolkata" />
          <div style={{ marginTop: 8 }}>
            <Button>Create clinic</Button>
          </div>
        </form>
      </Card>
    </main>
  );
}
