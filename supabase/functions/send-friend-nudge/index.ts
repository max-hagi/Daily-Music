// send-friend-nudge - validates a one-to-one friend nudge and sends APNs.
//
// Why an Edge Function? APNs token auth needs the APNs signing key, which must
// never ship in the app. This runs server-side: it reads the caller's JWT from
// the Authorization header (so a user can only nudge AS themselves), verifies
// the recipient is an accepted friend via are_friends(), enforces a 24h
// per-recipient cooldown from the friend_nudges audit table, and only then
// signs a provider JWT and pushes to the recipient's registered device tokens.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type PushToken = {
  token: string;
  environment: "sandbox" | "production";
};

type NudgeStatus = "sent" | "no_tokens" | "rate_limited" | "failed";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function base64url(input: string | ArrayBuffer): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\\n", "")
    .replaceAll("\n", "")
    .trim();
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function apnsJWT(): Promise<string> {
  const header = {
    alg: "ES256",
    kid: requiredEnv("APNS_KEY_ID"),
  };
  const claims = {
    iss: requiredEnv("APNS_TEAM_ID"),
    iat: Math.floor(Date.now() / 1000),
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(requiredEnv("APNS_PRIVATE_KEY")),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(signature)}`;
}

function apnsHost(environment: string): string {
  return environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
}

function notificationBody(senderName: string): string {
  return `${senderName} nudged you to check Daily Music.`;
}

function apnsPayload(senderName: string): Record<string, unknown> {
  return {
    aps: {
      alert: {
        title: "Daily Music",
        body: notificationBody(senderName),
      },
      sound: "default",
    },
    url: "dailymusic://today",
    type: "friend_nudge",
  };
}

async function insertAudit(
  admin: ReturnType<typeof createClient>,
  senderID: string,
  recipientID: string,
  status: NudgeStatus,
  apnsID: string | null = null,
  error: string | null = null,
) {
  await admin.from("friend_nudges").insert({
    sender_id: senderID,
    recipient_id: recipientID,
    status,
    apns_id: apnsID,
    error,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    const body = await req.json().catch(() => ({}));
    const recipientID = String(body.recipient_id ?? "");
    if (!recipientID) return json({ error: "Missing recipient_id" }, 400);

    const userClient = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_ANON_KEY"),
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Invalid or expired session" }, 401);

    const senderID = user.id;
    if (senderID === recipientID) return json({ error: "You cannot nudge yourself." }, 400);

    const admin = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );

    const { data: areFriends, error: friendError } = await admin.rpc("are_friends", {
      a: senderID,
      b: recipientID,
    });
    if (friendError) return json({ error: friendError.message }, 500);
    if (!areFriends) return json({ error: "You can only nudge accepted friends." }, 403);

    const cooldownStart = new Date(Date.now() - 86_400_000).toISOString();
    const { data: recentSent, error: recentError } = await admin
      .from("friend_nudges")
      .select("created_at")
      .eq("sender_id", senderID)
      .eq("recipient_id", recipientID)
      .eq("status", "sent")
      .gte("created_at", cooldownStart)
      .limit(1);
    if (recentError) return json({ error: recentError.message }, 500);
    if (recentSent && recentSent.length > 0) {
      const lastSentAt = new Date(recentSent[0].created_at).getTime();
      const nextAllowedAt = new Date(lastSentAt + 86_400_000).toISOString();
      await insertAudit(admin, senderID, recipientID, "rate_limited");
      return json({ status: "rate_limited", next_allowed_at: nextAllowedAt }, 200);
    }

    const { data: profile } = await admin
      .from("profiles")
      .select("display_name")
      .eq("id", senderID)
      .maybeSingle();
    const senderName = (profile?.display_name as string | undefined)?.trim() || "A friend";

    const configuredEnvironment = requiredEnv("APNS_ENVIRONMENT");
    if (configuredEnvironment !== "sandbox" && configuredEnvironment !== "production") {
      return json({ error: "APNS_ENVIRONMENT must be sandbox or production" }, 500);
    }

    const { data: tokens, error: tokenError } = await admin
      .from("push_tokens")
      .select("token,environment")
      .eq("user_id", recipientID)
      .eq("environment", configuredEnvironment);
    if (tokenError) return json({ error: tokenError.message }, 500);

    const pushTokens = (tokens ?? []) as PushToken[];
    if (pushTokens.length === 0) {
      await insertAudit(admin, senderID, recipientID, "no_tokens");
      return json({ status: "no_tokens" }, 200);
    }

    const jwt = await apnsJWT();
    const topic = requiredEnv("APNS_TOPIC");
    const payload = JSON.stringify(apnsPayload(senderName));
    const errors: string[] = [];
    const sentApnsIDs: string[] = [];

    for (const token of pushTokens) {
      const response = await fetch(`https://${apnsHost(configuredEnvironment)}/3/device/${token.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: payload,
      });

      // APNs returns an apns-id header on EVERY response, including rejections,
      // so success must be judged by the HTTP status (2xx), not by the header.
      const apnsID = response.headers.get("apns-id");
      if (response.ok) {
        if (apnsID) sentApnsIDs.push(apnsID);
      } else {
        const text = await response.text();
        errors.push(`${response.status}: ${text}`);
      }
    }

    if (sentApnsIDs.length > 0) {
      // At least one device accepted the push. Record any per-device rejections
      // (e.g. a stale token alongside a live one) in the audit error column.
      await insertAudit(
        admin,
        senderID,
        recipientID,
        "sent",
        sentApnsIDs.join(","),
        errors.length > 0 ? errors.join(" | ") : null,
      );
      return json({ status: "sent" }, 200);
    }

    await insertAudit(admin, senderID, recipientID, "failed", null, errors.join(" | "));
    return json({ status: "failed", error: "APNs rejected every registered device." }, 502);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
