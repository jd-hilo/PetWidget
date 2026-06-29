import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================
// generate-messages
// Cron: every 2–3 hours
// For each pet: fetch weather, call Claude, store message, push APNs
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;
const OPENWEATHER_API_KEY = Deno.env.get("OPENWEATHER_API_KEY")!;
// Team ID (JWT `iss`) is account-level, shared across all keys.
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID");
// Topic-specific APNs keys are restricted to a single environment, so we allow a distinct
// key per environment (`_DEV` = Sandbox, `_PROD` = Production). If those aren't set we fall
// back to a single team-scoped key (`APNS_KEY_ID` / `APNS_PRIVATE_KEY`) that works for both.
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID");
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY");
const APNS_KEY_ID_DEV = Deno.env.get("APNS_KEY_ID_DEV") ?? APNS_KEY_ID;
const APNS_PRIVATE_KEY_DEV = Deno.env.get("APNS_PRIVATE_KEY_DEV") ?? APNS_PRIVATE_KEY;
const APNS_KEY_ID_PROD = Deno.env.get("APNS_KEY_ID_PROD") ?? APNS_KEY_ID;
const APNS_PRIVATE_KEY_PROD = Deno.env.get("APNS_PRIVATE_KEY_PROD") ?? APNS_PRIVATE_KEY;
// `apns-topic` must equal the bundle id of the *installed* app. Debug and Release builds use
// different bundle ids (and map to the sandbox vs production APNs hosts), so the topic is chosen
// per device token based on its stored environment. Override via env if the ids change.
const APNS_TOPIC_PROD = Deno.env.get("APNS_TOPIC_PROD") ?? "com.hilollc.petmoji.app";
const APNS_TOPIC_DEV = Deno.env.get("APNS_TOPIC_DEV") ?? "com.hilollcpetmoji.app";

// Push is possible if we have a Team ID plus at least one usable key (env-specific or shared).
const APNS_CONFIGURED = Boolean(
  APNS_TEAM_ID &&
    ((APNS_KEY_ID_DEV && APNS_PRIVATE_KEY_DEV) ||
      (APNS_KEY_ID_PROD && APNS_PRIVATE_KEY_PROD)),
);

// Max scheduled AI messages delivered per pet per local day. Tunable via env without a redeploy;
// kept low by default to avoid feeling spammy. Location-triggered messages are not counted here.
const MAX_MESSAGES_PER_DAY = (() => {
  const raw = parseInt(Deno.env.get("MAX_MESSAGES_PER_DAY") ?? "2", 10);
  return Number.isFinite(raw) && raw > 0 ? raw : 2;
})();

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

interface Pet {
  id: string;
  user_id: string;
  name: string;
  species: string;
  personality_traits: string[];
  energy_level: number;
  biggest_enemy: string;
  base_mood: string;
  home_lat?: number;
  home_lng?: number;
  timezone: string;
}

interface Message {
  id: string;
  pet_id: string;
  content: string;
  expression: string;
}

Deno.serve(async (req: Request) => {
  // Can be triggered by cron or manually
  console.log("generate-messages triggered");

  try {
    // Fetch all pets
    const { data: pets, error } = await supabase
      .from("pets")
      .select("*");

    if (error) throw error;
    if (!pets?.length) {
      return new Response(JSON.stringify({ processed: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    let processed = 0;
    for (const pet of pets as Pet[]) {
      try {
        await processOnePet(pet);
        processed++;
      } catch (err) {
        console.error(`Failed to process pet ${pet.id}:`, err);
      }
    }

    return new Response(JSON.stringify({ processed }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("generate-messages error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

async function processOnePet(pet: Pet): Promise<void> {
  // 1. Enforce the daily cap on scheduled messages
  const today = new Date().toISOString().split("T")[0];
  const { count } = await supabase
    .from("messages")
    .select("*", { count: "exact", head: true })
    .eq("pet_id", pet.id)
    .eq("trigger_type", "scheduled")
    .gte("scheduled_for", `${today}T00:00:00Z`)
    .not("sent_at", "is", null);

  if ((count ?? 0) >= MAX_MESSAGES_PER_DAY) {
    console.log(`Pet ${pet.id} hit daily cap (${MAX_MESSAGES_PER_DAY} scheduled), skipping`);
    return;
  }

  // 2. Determine time context
  const tz = pet.timezone || "UTC";
  const localTime = getLocalTimeContext(tz);
  const triggerType = getScheduledTrigger(localTime.hour);

  if (!triggerType) {
    // Not within a scheduled message window
    return;
  }

  // 3. Fetch weather (if home location set)
  let weatherSummary: string | undefined;
  if (pet.home_lat && pet.home_lng) {
    try {
      weatherSummary = await fetchWeather(pet.home_lat, pet.home_lng);
    } catch {
      // Weather optional, don't fail
    }
  }

  // 4. Fetch last 10 sent messages to avoid repetition
  const { data: recentMessages } = await supabase
    .from("messages")
    .select("content")
    .eq("pet_id", pet.id)
    .not("sent_at", "is", null)
    .order("sent_at", { ascending: false })
    .limit(10);

  const recentContent = (recentMessages ?? []).map((m: { content: string }) => `- ${m.content}`).join("\n");

  // 5. Call Claude
  const response = await callClaude(pet, localTime.label, weatherSummary, triggerType, recentContent);

  // 6. Store message
  const now = new Date();
  const { data: message, error: insertError } = await supabase
    .from("messages")
    .insert({
      pet_id: pet.id,
      content: response.message,
      expression: response.expression,
      trigger_type: "scheduled",
      scheduled_for: now.toISOString(),
      sent_at: now.toISOString(),
    })
    .select()
    .single();

  if (insertError) throw insertError;

  // 7. Send a user-visible APNs push (also wakes the widget via content-available)
  if (APNS_CONFIGURED) {
    try {
      await sendPush(pet, message as Message);
    } catch (err) {
      console.warn("APNs push failed (non-fatal):", err);
    }
  } else {
    console.warn("APNs not configured (need APNS_TEAM_ID + a DEV or PROD key); skipping push");
  }

  console.log(`Message sent for pet ${pet.id}: "${response.message}" [${response.expression}]`);
}

// ============================================================
// Time context
// ============================================================

function getLocalTimeContext(timezone: string): { hour: number; label: string } {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "numeric",
      hour12: false,
    });
    const hour = parseInt(formatter.format(new Date()), 10);
    return { hour, label: getTimeLabel(hour) };
  } catch {
    const hour = new Date().getHours();
    return { hour, label: getTimeLabel(hour) };
  }
}

function getTimeLabel(hour: number): string {
  if (hour >= 7 && hour < 9) return "morning (7–9am)";
  if (hour >= 12 && hour < 14) return "midday (12–2pm)";
  if (hour >= 15 && hour < 17) return "afternoon (3–5pm)";
  if (hour >= 19 && hour < 21) return "evening (7–9pm)";
  if (hour >= 22 || hour < 5) return "late night (10pm+)";
  return `${hour}:00`;
}

function getScheduledTrigger(hour: number): string | null {
  // Only send during scheduled windows
  if (hour >= 7 && hour < 9) return "morning";
  if (hour >= 12 && hour < 14) return "midday";
  if (hour >= 15 && hour < 17) return "afternoon";
  if (hour >= 19 && hour < 21) return "evening";
  if (hour >= 22 || hour < 1) return "night";
  return null;
}

// ============================================================
// Weather
// ============================================================

async function fetchWeather(lat: number, lng: number): Promise<string> {
  const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lng}&appid=${OPENWEATHER_API_KEY}&units=imperial`;
  const res = await fetch(url);
  if (!res.ok) throw new Error("Weather API failed");
  const data = await res.json();

  const condition = data.weather?.[0]?.main ?? "Clear";
  const temp = Math.round(data.main?.temp ?? 70);
  const description = data.weather?.[0]?.description ?? "clear sky";

  // Only surface notable weather
  const notable = ["Rain", "Snow", "Thunderstorm", "Extreme"].includes(condition) ||
    temp < 32 || temp > 90;

  if (!notable) return "";
  return `${condition} (${temp}°F, ${description})`;
}

// ============================================================
// Claude message generation
// ============================================================

async function callClaude(
  pet: Pet,
  timeLabel: string,
  weather: string | undefined,
  triggerType: string,
  recentMessages: string
): Promise<{ message: string; expression: string }> {
  const systemPrompt = `You are ${pet.name}, a ${pet.species}. Your personality: ${pet.personality_traits.join(", ")}. Energy level: ${pet.energy_level} out of 10. Things that set you off: ${pet.biggest_enemy}. Your general vibe: ${pet.base_mood}. Speak in first person. Be short, dry, and a little dramatic. Max 80 characters total. Never break character.`;

  const userPrompt = `Time of day: ${timeLabel}
${weather ? `Weather: ${weather}` : ""}
Trigger: scheduled ${triggerType} message

Recent messages you've already sent (do NOT repeat or closely echo these):
${recentMessages || "(none yet)"}

Return ONLY valid JSON: { "message": "string max 80 chars", "expression": "happy"|"sleepy"|"mad"|"excited"|"misses_you"|"judging" }`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": CLAUDE_API_KEY,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 150,
      system: systemPrompt,
      messages: [{ role: "user", content: userPrompt }],
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error: ${errText}`);
  }

  const data = await res.json();
  const text: string = data.content?.[0]?.text ?? "";

  // Extract JSON from Claude's response
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error(`Could not parse Claude response: ${text}`);

  const parsed = JSON.parse(jsonMatch[0]);
  const message = (parsed.message as string).slice(0, 80);
  const expression = parsed.expression ?? "happy";

  return { message, expression };
}

// ============================================================
// APNs Push (user-visible alert + content-available widget wake)
// ============================================================

interface DeviceToken {
  token: string;
  environment: "development" | "production";
}

async function sendPush(pet: Pet, message: Message): Promise<void> {
  // Look up every device token registered for this pet's owner.
  const { data: tokens, error } = await supabase
    .from("device_tokens")
    .select("token, environment")
    .eq("user_id", pet.user_id);

  if (error) throw error;
  if (!tokens?.length) {
    console.log(`No device tokens for user ${pet.user_id}; skipping push`);
    return;
  }

  const payload = JSON.stringify({
    aps: {
      alert: { title: pet.name, body: message.content },
      sound: "default",
      "content-available": 1,
    },
    pet_id: message.pet_id,
    trigger: "scheduled",
  });

  for (const device of tokens as DeviceToken[]) {
    try {
      await sendToToken(device, payload);
    } catch (err) {
      console.warn(`APNs send failed for token ${device.token.slice(0, 8)}…:`, err);
    }
  }
}

async function sendToToken(device: DeviceToken, payload: string): Promise<void> {
  const isProd = device.environment === "production";
  const creds = apnsCredsFor(device.environment);
  if (!creds) {
    console.warn(
      `No APNs key configured for ${device.environment}; skipping token ${device.token.slice(0, 8)}…`,
    );
    return;
  }
  const host = isProd ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
  const topic = isProd ? APNS_TOPIC_PROD : APNS_TOPIC_DEV;
  const jwt = await getAPNsJWT(creds);

  const res = await fetch(`${host}/3/device/${device.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: payload,
  });

  if (res.status === 200) return;

  const reason = await res.text();
  // Remove tokens APNs reports as permanently invalid so they stop being retried.
  if (res.status === 410 || reason.includes("BadDeviceToken") || reason.includes("Unregistered")) {
    await supabase.from("device_tokens").delete().eq("token", device.token);
  }
  throw new Error(`APNs ${res.status}: ${reason}`);
}

// ============================================================
// APNs provider JWT (ES256), cached per key and refreshed hourly
// ============================================================

interface APNsCreds {
  keyId: string;
  privateKey: string;
}

/// Resolves the APNs key for a token's environment, preferring the env-specific key and
/// falling back to the shared team-scoped key. Returns null if none is configured.
function apnsCredsFor(environment: "development" | "production"): APNsCreds | null {
  const keyId = environment === "production" ? APNS_KEY_ID_PROD : APNS_KEY_ID_DEV;
  const privateKey = environment === "production" ? APNS_PRIVATE_KEY_PROD : APNS_PRIVATE_KEY_DEV;
  if (!keyId || !privateKey || !APNS_TEAM_ID) return null;
  return { keyId, privateKey };
}

// Cache one provider token per key id (different environments may use different keys).
const jwtCache = new Map<string, { token: string; issuedAt: number }>();

async function getAPNsJWT(creds: APNsCreds): Promise<string> {
  // APNs accepts a provider token for up to 1 hour; reuse it and refresh well before expiry.
  const now = Math.floor(Date.now() / 1000);
  const cached = jwtCache.get(creds.keyId);
  if (cached && now - cached.issuedAt < 50 * 60) {
    return cached.token;
  }

  const header = { alg: "ES256", kid: creds.keyId };
  const claims = { iss: APNS_TEAM_ID, iat: now };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;

  const key = await importAPNsKey(creds.privateKey);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const token = `${signingInput}.${base64urlBytes(new Uint8Array(signature))}`;
  jwtCache.set(creds.keyId, { token, issuedAt: now });
  return token;
}

async function importAPNsKey(pem: string): Promise<CryptoKey> {
  // Accept the .p8 contents with or without PEM armor / escaped newlines.
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

function base64url(input: string): string {
  return base64urlBytes(new TextEncoder().encode(input));
}

function base64urlBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
