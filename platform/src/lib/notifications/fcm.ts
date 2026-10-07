import { SignJWT, importPKCS8 } from "jose";
import { db } from "../db.js";
import { env } from "../env.js";

/**
 * Firebase Cloud Messaging (HTTP v1) sender. Inert unless
 * FCM_SERVICE_ACCOUNT_JSON is set. Uses a service-account JWT exchanged for a
 * short-lived OAuth token (cached), so no Firebase Admin SDK is needed.
 */
interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let parsed: ServiceAccount | null | undefined;

function serviceAccount(): ServiceAccount | null {
  if (parsed !== undefined) return parsed;
  const raw = env.FCM_SERVICE_ACCOUNT_JSON.trim();
  if (!raw) return (parsed = null);
  try {
    const text = raw.startsWith("{") ? raw : Buffer.from(raw, "base64").toString("utf8");
    const json = JSON.parse(text) as Partial<ServiceAccount>;
    if (!json.project_id || !json.client_email || !json.private_key) return (parsed = null);
    return (parsed = json as ServiceAccount);
  } catch {
    return (parsed = null);
  }
}

export function fcmConfigured(): boolean {
  return serviceAccount() !== null;
}

let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;
  const key = await importPKCS8(sa.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
    signal: AbortSignal.timeout(8_000),
  });
  if (!res.ok) throw new Error(`FCM auth failed (${res.status})`);
  const json = (await res.json()) as { access_token: string; expires_in: number };
  cachedToken = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return json.access_token;
}

export interface PushMessage {
  title: string;
  body: string;
  /** Routing data for the app (all values must be strings). */
  data?: Record<string, string>;
}

export interface PushResult {
  /** Phones the message reached. */
  sent: number;
  /** Transient failures — worth retrying later. */
  failed: number;
  /** The user has no registered phones; nothing to retry. */
  noDevices: boolean;
}

/**
 * Send to every phone registered for `userId`. Tokens FCM reports as dead
 * (app uninstalled, token rotated) are deleted so they are never retried.
 */
export async function sendPushToUser(userId: string, message: PushMessage): Promise<PushResult> {
  const sa = serviceAccount();
  if (!sa) return { sent: 0, failed: 0, noDevices: true };
  const devices = await db.deviceToken.findMany({ where: { userId }, select: { token: true } });
  if (devices.length === 0) return { sent: 0, failed: 0, noDevices: true };

  const bearer = await accessToken(sa);
  let sent = 0;
  let failed = 0;
  await Promise.all(
    devices.map(async ({ token }) => {
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
            body: JSON.stringify({
              message: {
                token,
                notification: { title: message.title, body: message.body },
                data: message.data ?? {},
                android: {
                  priority: "HIGH",
                  notification: { channel_id: "clinic_updates", sound: "default" },
                },
                apns: { payload: { aps: { sound: "default" } } },
              },
            }),
            signal: AbortSignal.timeout(8_000),
          },
        );
        if (res.ok) {
          sent += 1;
          return;
        }
        const text = await res.text();
        if (res.status === 404 || /UNREGISTERED|registration-token-not-registered/i.test(text)) {
          await db.deviceToken.deleteMany({ where: { token } });
          return;
        }
        failed += 1;
      } catch {
        failed += 1;
      }
    }),
  );
  return { sent, failed, noDevices: false };
}
