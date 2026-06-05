import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================
// delete-account
// Permanently deletes the authenticated user, their profile,
// pets, messages, device tokens, and stored photos/sprites.
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const SPRITE_EXPRESSIONS = [
  "happy",
  "sleepy",
  "mad",
  "excited",
  "misses_you",
  "judging",
];

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const { data: pets, error: petsError } = await admin
    .from("pets")
    .select("id")
    .eq("user_id", user.id);

  if (petsError) {
    return new Response(JSON.stringify({ error: petsError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  for (const pet of pets ?? []) {
    const photoPaths = Array.from({ length: 5 }, (_, i) => `${pet.id}/photo_${i}.jpg`);
    await admin.storage.from("pet-photos").remove(photoPaths);

    const spritePaths = SPRITE_EXPRESSIONS.map((expression) => `${pet.id}/${expression}.png`);
    await admin.storage.from("pet-sprites").remove(spritePaths);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
