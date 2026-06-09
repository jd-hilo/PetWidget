import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================
// chat-reply
// Conversational pet chat — multi-turn Claude with personality.
// Persists replies to messages (trigger_type: chat_reply).
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

interface HistoryMessage {
  role: "user" | "assistant";
  content: string;
}

interface ChatRequest {
  pet_id: string;
  message: string;
  history?: HistoryMessage[];
  owner_name?: string;
  is_opening?: boolean;
}

interface Pet {
  id: string;
  user_id: string;
  name: string;
  species: string;
  personality_traits: string[];
  energy_level: number;
  biggest_enemy: string;
  base_mood: string;
  timezone: string;
}

const VALID_EXPRESSIONS = new Set([
  "happy",
  "sleepy",
  "mad",
  "excited",
  "misses_you",
  "judging",
]);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  try {
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const body: ChatRequest = await req.json();
    const { pet_id, message, history = [], owner_name, is_opening = false } = body;

    if (!pet_id) {
      return new Response(JSON.stringify({ error: "pet_id required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!is_opening && !message?.trim()) {
      return new Response(JSON.stringify({ error: "message required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: petRow, error: petAccessError } = await userClient
      .from("pets")
      .select("id, user_id, name, species, personality_traits, energy_level, biggest_enemy, base_mood, timezone")
      .eq("id", pet_id)
      .single();

    if (petAccessError || !petRow) {
      return new Response(JSON.stringify({ error: "Pet not found or access denied" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    const pet = petRow as Pet;

    let ownerName = owner_name?.trim() || "";
    if (!ownerName) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("id", user.id)
        .single();
      ownerName = (profile?.full_name as string | undefined)?.trim() || "my human";
    }

    const { data: recentMessages } = await supabase
      .from("messages")
      .select("content")
      .eq("pet_id", pet_id)
      .not("sent_at", "is", null)
      .order("sent_at", { ascending: false })
      .limit(10);

    const recentContent = (recentMessages ?? [])
      .map((m: { content: string }) => `- ${m.content}`)
      .join("\n");

    const localTime = getLocalTimeContext(pet.timezone || "UTC");
    const systemPrompt = buildChatSystemPrompt(pet, ownerName, recentContent);

    const claudeMessages = buildClaudeMessages({
      history,
      message: message?.trim() ?? "",
      isOpening: is_opening,
      timeLabel: localTime.label,
    });

    const response = await callClaude(systemPrompt, claudeMessages);

    const now = new Date();
    const { data: stored, error: insertError } = await supabase
      .from("messages")
      .insert({
        pet_id,
        content: response.message,
        expression: response.expression,
        trigger_type: "chat_reply",
        scheduled_for: now.toISOString(),
        sent_at: now.toISOString(),
      })
      .select()
      .single();

    if (insertError) throw insertError;

    console.log(`[chat-reply] pet=${pet_id} expr=${response.expression}: "${response.message}"`);

    return new Response(
      JSON.stringify({
        message: response.message,
        expression: response.expression,
        id: stored.id,
        pet_id: stored.pet_id,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[chat-reply] error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

function buildChatSystemPrompt(pet: Pet, ownerName: string, recentMessages: string): string {
  const traits = Array.isArray(pet.personality_traits)
    ? pet.personality_traits.join(", ")
    : "friendly";
  return (
    `You are ${pet.name}, a ${pet.species}. You are texting your owner ${ownerName}. ` +
    `Personality: ${traits}. Energy: ${pet.energy_level}/10. ` +
    `Things that set you off: ${pet.biggest_enemy}. General vibe: ${pet.base_mood}. ` +
    `Speak in first person as the pet. Never break character or mention being an AI.\n\n` +
    `CHAT RULES (this is a conversation, not a widget notification):\n` +
    `- Reply like a real text thread with your owner\n` +
    `- Usually 1 short sentence (under ~120 characters); use 2–3 sentences only when they share something detailed or emotional\n` +
    `- Respond directly to what they just said; reference earlier messages in the thread when relevant\n` +
    `- Occasionally ask a natural follow-up question (not every reply)\n` +
    `- Vary your wording; do not repeat or closely echo your recent messages\n` +
    `- Do not use emojis in most replies; plain text only. An emoji is fine only rarely for strong emphasis (at most one, and skip emojis entirely in most messages)\n` +
    `- Pick an expression that matches your tone in this reply\n\n` +
    `Recent messages you have already sent (do NOT repeat or closely echo):\n` +
    `${recentMessages || "(none yet)"}\n\n` +
    `Return ONLY valid JSON: { "message": "string", "expression": "happy"|"sleepy"|"mad"|"excited"|"misses_you"|"judging" }`
  );
}

function buildClaudeMessages(args: {
  history: HistoryMessage[];
  message: string;
  isOpening: boolean;
  timeLabel: string;
}): Array<{ role: "user" | "assistant"; content: string }> {
  const trimmedHistory = args.history
    .filter((m) => m.content?.trim())
    .slice(-20)
    .map((m) => ({
      role: m.role,
      content: m.content.trim(),
    }));

  if (args.isOpening) {
    return [
      ...trimmedHistory,
      {
        role: "user" as const,
        content:
          `The owner just opened chat. Time of day: ${args.timeLabel}. ` +
          `Greet them naturally in character — one short line. You may reference the time of day if it fits.`,
      },
    ];
  }

  return [
    ...trimmedHistory,
    { role: "user" as const, content: args.message },
  ];
}

async function callClaude(
  systemPrompt: string,
  messages: Array<{ role: "user" | "assistant"; content: string }>,
): Promise<{ message: string; expression: string }> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": CLAUDE_API_KEY,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 300,
      system: systemPrompt,
      messages,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error: ${errText}`);
  }

  const data = await res.json();
  const text: string = data.content?.[0]?.text ?? "";

  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error(`Could not parse Claude response: ${text}`);

  const parsed = JSON.parse(jsonMatch[0]);
  const message = String(parsed.message ?? "").trim();
  if (!message) throw new Error("Claude returned empty message");

  let expression = String(parsed.expression ?? "happy");
  if (!VALID_EXPRESSIONS.has(expression)) expression = "happy";

  return { message, expression };
}

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
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  if (hour >= 21 || hour < 5) return "late night";
  return `${hour}:00`;
}
