// delete-account — permanently deletes the calling user's account and data.
//
// Why an Edge Function? The iOS app only ships the ANON key, which (by design)
// cannot delete an auth.users row. This function runs server-side with the
// SERVICE_ROLE key, so it can remove the user's data rows and then the auth
// user itself. The caller's JWT is read from the Authorization header, so a user
// can only ever delete THEMSELVES — no user id is accepted from the client.
//
// Deploy:
//   supabase functions deploy delete-account
// (SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY are injected
//  automatically by the Supabase platform — you do not set them by hand.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    // 1. Identify the caller from their JWT (anon client scoped to their token).
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) {
      return json({ error: "Invalid or expired session" }, 401);
    }
    const uid = user.id;

    // 2. Admin client (service role) — bypasses RLS and can delete the auth user.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 3. Remove the user's data. If your foreign keys use ON DELETE CASCADE
    //    against auth.users(id), step 4 alone is enough and these are harmless
    //    no-ops. Kept explicit so deletion is complete regardless of FK setup.
    await admin.from("reactions").delete().eq("user_id", uid);
    await admin.from("check_ins").delete().eq("user_id", uid);
    await admin.from("favourites").delete().eq("user_id", uid);
    await admin.from("song_ratings").delete().eq("user_id", uid);
    await admin.from("profiles").delete().eq("id", uid); // profiles keyed by id = auth uid

    // 4. Delete the auth user itself.
    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) {
      return json({ error: `Failed to delete user: ${delErr.message}` }, 500);
    }

    return json({ success: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
