// Account deletion. Required by App Store Guideline 5.1.1(v): any app that lets
// users create an account must let them delete it from inside the app.
//
// This has to run server-side. A client holding the anon key can sign itself out
// but cannot delete its own auth record -- that needs the service role key, which
// must never ship inside an app binary.
//
// Deploy:  supabase functions deploy delete-account
// The SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars are injected by Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST required" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "missing bearer token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const jwt = authHeader.slice("Bearer ".length);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  // Resolve the caller from their own token. The client never sends a user id --
  // that would let anyone delete anyone.
  const { data: { user }, error: lookupError } = await admin.auth.getUser(jwt);
  if (lookupError || !user) {
    return new Response(JSON.stringify({ error: "invalid token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // study_sessions.user_id cascades from auth.users, so this removes the
  // account and every session belonging to it together.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
