import { type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID");
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY");

export interface PetMessagePushData {
  pet_id: string;
  message_id: string;
  trigger: string;
}

export async function sendSilentPetMessagePush(
  userId: string,
  data: PetMessagePushData,
): Promise<void> {
  if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
    console.warn("OneSignal not configured, skipping push");
    return;
  }

  const res = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Key ${ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      include_aliases: { external_id: [userId] },
      content_available: true,
      priority: 10,
      data,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OneSignal push failed (${res.status}): ${err}`);
  }
}

export async function userNotificationsEnabled(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("profiles")
    .select("notifications_enabled")
    .eq("id", userId)
    .maybeSingle();

  return data?.notifications_enabled !== false;
}
