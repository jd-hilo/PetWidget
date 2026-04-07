import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const REPLICATE_API_TOKEN = Deno.env.get("REPLICATE_API_TOKEN")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// All 6 expressions we generate per pet
const EXPRESSIONS = [
  { key: "happy", modifier: "smiling, bright eyes, happy expression, cheerful" },
  { key: "sleepy", modifier: "half-closed eyes, drowsy, yawning, tired" },
  { key: "mad", modifier: "furrowed brow, grumpy expression, angry, annoyed" },
  { key: "excited", modifier: "wide eyes, open mouth, ears perked up, very excited" },
  { key: "misses_you", modifier: "sad eyes, droopy ears, looking up with longing, sad" },
  { key: "judging", modifier: "one eyebrow raised, unimpressed stare, side-eye, judgmental" },
] as const;

interface GenerateRequest {
  pet_id: string;
  photo_urls: string[];
  pet_name: string;
  species: string;
}

interface ExpressionMap {
  happy?: string;
  sleepy?: string;
  mad?: string;
  excited?: string;
  misses_you?: string;
  judging?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body: GenerateRequest = await req.json();
    const { pet_id, photo_urls, pet_name, species } = body;

    if (!pet_id || !photo_urls?.length) {
      return new Response(JSON.stringify({ error: "pet_id and photo_urls required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Use the first (best) photo as primary input
    const primaryPhotoURL = photo_urls[0];

    console.log(`Generating sprites for pet ${pet_id} (${pet_name}, ${species})`);

    // Generate all expressions in parallel
    const expressionResults = await Promise.allSettled(
      EXPRESSIONS.map(async (expr) => {
        const imageURL = await generateSprite(primaryPhotoURL, pet_name, species, expr.modifier);
        const storedURL = await storeSprite(pet_id, expr.key, imageURL);
        return { key: expr.key, url: storedURL };
      })
    );

    // Build expression map
    const expressionMap: ExpressionMap = {};
    for (const result of expressionResults) {
      if (result.status === "fulfilled") {
        const { key, url } = result.value;
        (expressionMap as Record<string, string>)[key] = url;
      }
    }

    // Update pet record with generated expressions
    const { error: updateError } = await supabase
      .from("pets")
      .update({ expressions: expressionMap })
      .eq("id", pet_id);

    if (updateError) {
      throw new Error(`Failed to update pet: ${updateError.message}`);
    }

    console.log(`Sprites generated for pet ${pet_id}:`, expressionMap);

    return new Response(JSON.stringify(expressionMap), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Sprite generation error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

// ============================================================
// Replicate API — face-to-sticker / cartoon portrait
// ============================================================

async function generateSprite(
  photoURL: string,
  petName: string,
  species: string,
  expressionModifier: string
): Promise<string> {
  const basePrompt = `cute cartoon ${species} portrait, Memoji style, clean rounded cartoon, smooth shading, expressive face, simplified but recognizable features, transparent background, sticker art, ${expressionModifier}`;

  // Try fofr/face-to-sticker first (best style match)
  try {
    const imageURL = await replicatePredict(
      "fofr/face-to-sticker:764d4827ea159608a07cdde8ddf1c6000019627515eb02b6b449695fd547e5ef",
      {
        image: photoURL,
        prompt: basePrompt,
        negative_prompt: "realistic, photograph, blurry, ugly, text, watermark",
        steps: 20,
        style: "Sticker",
        upscale: false,
        upscale_steps: 10,
        seed: -1,
        width: 512,
        height: 512,
      }
    );
    return imageURL;
  } catch (err) {
    console.warn("face-to-sticker failed, falling back to SDXL:", err);
  }

  // Fallback: SDXL img2img
  return await replicatePredict(
    "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
    {
      image: photoURL,
      prompt: basePrompt,
      negative_prompt: "realistic, photograph, blurry, ugly, text, watermark, background",
      prompt_strength: 0.6,
      num_inference_steps: 30,
      guidance_scale: 7.5,
      width: 512,
      height: 512,
    }
  );
}

async function replicatePredict(
  version: string,
  input: Record<string, unknown>
): Promise<string> {
  // Start prediction
  const startRes = await fetch("https://api.replicate.com/v1/predictions", {
    method: "POST",
    headers: {
      "Authorization": `Token ${REPLICATE_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ version, input }),
  });

  if (!startRes.ok) {
    throw new Error(`Replicate start failed: ${await startRes.text()}`);
  }

  const prediction = await startRes.json();
  const predictionId = prediction.id;

  // Poll for completion (max 60 seconds)
  const maxAttempts = 30;
  for (let i = 0; i < maxAttempts; i++) {
    await sleep(2000);

    const pollRes = await fetch(`https://api.replicate.com/v1/predictions/${predictionId}`, {
      headers: { "Authorization": `Token ${REPLICATE_API_TOKEN}` },
    });

    const status = await pollRes.json();

    if (status.status === "succeeded") {
      const output = Array.isArray(status.output) ? status.output[0] : status.output;
      if (!output) throw new Error("Replicate returned empty output");
      return output as string;
    }

    if (status.status === "failed") {
      throw new Error(`Replicate prediction failed: ${status.error}`);
    }
  }

  throw new Error("Replicate prediction timed out");
}

async function storeSprite(petId: string, expression: string, imageURL: string): Promise<string> {
  // Download generated image
  const res = await fetch(imageURL);
  if (!res.ok) throw new Error(`Failed to download sprite: ${res.statusText}`);
  const imageData = await res.arrayBuffer();

  // Upload to Supabase Storage
  const path = `${petId}/${expression}.png`;
  const { error } = await supabase.storage
    .from("pet-sprites")
    .upload(path, imageData, {
      contentType: "image/png",
      upsert: true,
    });

  if (error) throw new Error(`Storage upload failed: ${error.message}`);

  // Return public URL
  const { data } = supabase.storage.from("pet-sprites").getPublicUrl(path);
  return data.publicUrl;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
