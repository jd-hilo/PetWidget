import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================
// location-event
// Called by iOS app on geofence trigger (left_home | returned)
// Immediately generates and stores a priority message
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

interface LocationRequest {
  pet_id: string;
  event: "left_home" | "returned";
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body: LocationRequest = await req.json();
    const { pet_id, event } = body;

    if (!pet_id || !event) {
      return new Response(JSON.stringify({ error: "pet_id and event required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Fetch pet
    const { data: pet, error: petError } = await supabase
      .from("pets")
      .select("*")
      .eq("id", pet_id)
      .single();

    if (petError || !pet) {
      return new Response(JSON.stringify({ error: "Pet not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Fetch recent messages to avoid repetition
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

    // Generate message for this event
    const response = await generateLocationMessage(pet, event, recentContent);

    // Store message
    const now = new Date();
    const triggerType = event === "left_home" ? "left_home" : "returned";

    const { data: message, error: insertError } = await supabase
      .from("messages")
      .insert({
        pet_id,
        content: response.message,
        expression: response.expression,
        trigger_type: triggerType,
        scheduled_for: now.toISOString(),
        sent_at: now.toISOString(),
      })
      .select()
      .single();

    if (insertError) throw insertError;

    console.log(`Location message for pet ${pet_id} (${event}): "${response.message}"`);

    return new Response(JSON.stringify(message), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("location-event error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

interface Pet {
  name: string;
  species: string;
  personality_traits: string[];
  energy_level: number;
  biggest_enemy: string;
  base_mood: string;
}

async function generateLocationMessage(
  pet: Pet,
  event: string,
  recentMessages: string
): Promise<{ message: string; expression: string }> {
  const eventContext = event === "left_home"
    ? "The owner just left home. The pet is reacting to being left alone."
    : "The owner just came back home after being away. The pet is reacting to their return.";

  const systemPrompt = `You are ${pet.name}, a ${pet.species}. Personality: ${pet.personality_traits.join(", ")}. Energy: ${pet.energy_level}/10. Things that set you off: ${pet.biggest_enemy}. Vibe: ${pet.base_mood}. Speak in first person, short and dramatic. Max 80 characters.`;

  const userPrompt = `${eventContext}

Recent messages (do NOT repeat):
${recentMessages || "(none)"}

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

  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error(`Could not parse response: ${text}`);

  const parsed = JSON.parse(jsonMatch[0]);
  return {
    message: (parsed.message as string).slice(0, 80),
    expression: parsed.expression ?? (event === "left_home" ? "misses_you" : "excited"),
  };
}
