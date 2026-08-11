import { type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID");
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY");

export interface PetMessagePushData {
  pet_id: string;
  message_id: string;
  trigger: string;
  /** Used by the Notification Service Extension to update the widget without opening the app. */
  expression?: string;
  pet_name?: string;
  message?: string;
  sprite_url?: string;
}

export interface PetMessagePushOptions {
  /** Shown as the notification title (pet name). Required for TestFlight reliability. */
  title?: string;
  /** Shown as the notification body (message text). Required for TestFlight reliability. */
  body?: string;
}

/**
 * Sends a OneSignal push to the user identified by Supabase user id (`external_id`).
 *
 * Always includes `content_available` so a running/background app can refresh chat + widget.
 * When title/body are provided, also sends a visible alert — silent-only pushes often never
 * wake a killed TestFlight/App Store build.
 *
 * `mutable_content` wakes the Notification Service Extension so the home-screen widget can
 * update even when the main app is killed.
 */
export async function sendSilentPetMessagePush(
  userId: string,
  data: PetMessagePushData,
  options: PetMessagePushOptions = {},
): Promise<void> {
  if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
    console.warn("OneSignal not configured, skipping push");
    return;
  }

  // iOS `UUID.uuidString` is uppercase; OneSignal aliases are case-sensitive.
  const externalId = userId.toUpperCase();

  const payload: Record<string, unknown> = {
    app_id: ONESIGNAL_APP_ID,
    target_channel: "push",
    include_aliases: { external_id: [externalId] },
    content_available: true,
    mutable_content: true,
    priority: 10,
    data,
  };

  if (options.title || options.body) {
    payload.headings = { en: options.title ?? "Petmoji" };
    payload.contents = { en: options.body ?? "New message from your pet" };
  }

  const res = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Key ${ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  const bodyText = await res.text();
  let parsed: Record<string, unknown> = {};
  try {
    parsed = JSON.parse(bodyText) as Record<string, unknown>;
  } catch {
    parsed = { raw: bodyText };
  }

  if (!res.ok) {
    throw new Error(`OneSignal push failed (${res.status}): ${bodyText}`);
  }

  const recipients = parsed.recipients;
  console.log(
    `OneSignal push ok id=${parsed.id ?? "?"} recipients=${recipients ?? "?"} errors=${JSON.stringify(parsed.errors ?? null)}`,
  );

  // 0 recipients = no subscribed device for this external_id (OneSignal.login never ran / wrong app id / revoked key)
  if (recipients === 0 || parsed.errors) {
    throw new Error(
      `OneSignal push not delivered for external_id=${externalId}: recipients=${recipients ?? "?"} errors=${JSON.stringify(parsed.errors ?? null)}`,
    );
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
