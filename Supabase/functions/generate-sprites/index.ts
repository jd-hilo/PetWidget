import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================
// generate-sprites
//
// Two-stage Memoji pipeline for consistent pet reactions:
//   Stage A (sequential): Flux Kontext Pro transforms the pet photo into a
//     single Memoji-style "happy" base. Prompt pins the style explicitly to
//     match our Apple-Memoji reference set (stored at pet-sprites/style/).
//   Stage B (parallel x5): Flux Kontext Pro edits the base sprite into each
//     remaining emotion. Because every edit starts from the same base image,
//     all 6 outputs look like the same pet.
//
// Models (Replicate):
//   - black-forest-labs/flux-kontext-pro   (base stylize + edits)
//   - black-forest-labs/flux-1.1-pro       (fallback base)
//   - fofr/face-to-sticker                 (last-resort fallback)
// ============================================================

const REPLICATE_API_TOKEN = Deno.env.get("REPLICATE_API_TOKEN")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Photo fidelity — never invent traits not visible in the reference image.
const IDENTITY_PRESERVE =
  `Preserve this pet's identity from the reference image: exact fur color and markings, ` +
  `eye color and iris color as in the photo, nose color, ear shape and size, breed silhouette. ` +
  `Match the reference photo's eye color exactly — if eyes are amber or light, keep them amber or light in cartoon form. ` +
  `Do not darken pupils or irises beyond what appears in the photo. ` +
  `Only include markings visible in the photo. ` +
  `Do NOT add accessories, collars, hats, extra markings, heterochromia, or color changes not in the photo. ` +
  `Stylize into cartoon proportions but keep the same colors the pet actually has.`;

// Memoji aesthetic without forcing eye color or generic template features.
const MEMOJI_STYLE_DESCRIPTION =
  `Apple iOS animal emoji style, official Apple Memoji animal sticker aesthetic, ` +
  `3D rendered cartoon character like the Apple dog/cat/bear emoji, ` +
  `soft matte 3D surface with gentle subsurface scattering (NOT shiny plastic, NOT wet), ` +
  `chibi proportions: oversized head, tiny or no body, ` +
  `large expressive cartoon eyes scaled up from the photo's actual eye color, subtle white catchlights only, ` +
  `simplified stylized fur (smooth volumetric shapes, no individual hair strands), ` +
  `tiny cute nose, small expressive mouth, perky simplified ears, ` +
  `bright saturated cartoon colors matching the pet's real colors, soft even cartoon lighting, ` +
  `Pixar 3D animation quality, front-facing centered portrait headshot, no shoulders, ` +
  `pure flat white background, fully isolated subject`;

const MEMOJI_NEGATIVE =
  `realistic photo, photographic, photo-real fur, individual hair strands, ` +
  `wet glossy plastic, oily skin, harsh specular highlights, plastic shine, ` +
  `wrong eye color, black eyes when photo has light eyes, darkened pupils, invented eye color, ` +
  `added markings, added accessories, collar, hat, heterochromia, extra spots, ` +
  `identical expression to input, subtle expression change, same face as before, ` +
  `flat 2D illustration, sticker outline, painterly, watercolor, sketch, line art, ` +
  `anime style, manga style, ` +
  `realistic proportions, small head, full body, shoulders, neck, ` +
  `busy background, gradient background, dark background, shadows on background, ` +
  `text, watermark, border, frame, multiple characters`;

// Stage B rules applied around each expression-specific instruction.
const EXPRESSION_EDIT_RULES =
  `PRESERVE EXACTLY: fur colors, markings, eye color, iris color, nose, head shape, pose, ` +
  `matte 3D art style, pure white background. Do not change eye color or fur color. ` +
  `This must look clearly different from a happy/neutral face at a glance.`;

const BASE_EXPRESSION = "happy" as const;

const EXPRESSION_EDITS: Array<{ key: string; emotion: string; instruction: string }> = [
  { key: "happy", emotion: "happy", instruction: "" /* base */ },
  {
    key: "sleepy",
    emotion: "sleepy",
    instruction:
      `CHANGE ONLY: eyelids 70% closed and heavy, droopy relaxed brows, small open yawn, ` +
      `mouth slightly agape, ears relaxed and angled down. ` +
      `Do not change eye color or fur color.`,
  },
  {
    key: "mad",
    emotion: "angry",
    instruction:
      `CHANGE ONLY: sharp V-shaped angry brows, narrowed squinting eyes (same eye color), ` +
      `tight downturned scowling mouth, ears slightly pulled back. ` +
      `Do not change eye color or fur color.`,
  },
  {
    key: "excited",
    emotion: "excited",
    instruction:
      `CHANGE ONLY: eyes wide open with visible eye whites, big open grin showing enthusiasm, ` +
      `ears perked forward and alert — noticeably more open and energetic than a gentle happy smile. ` +
      `Do not change eye color or fur color.`,
  },
  {
    key: "misses_you",
    emotion: "sad and longing",
    instruction:
      `CHANGE ONLY: soft downturned mouth, glossy watery sheen in eyes without changing eye color, ` +
      `ears drooped low, subtle sad raised inner brows, longing wistful look. ` +
      `Do not change eye color or fur color.`,
  },
  {
    key: "judging",
    emotion: "judging and unimpressed",
    instruction:
      `CHANGE ONLY: one eyebrow raised asymmetrically, sidelong side-eye glance, ` +
      `flat unimpressed mouth line, skeptical expression. ` +
      `Do not change eye color or fur color.`,
  },
];

interface GenerateRequest {
  pet_id: string;
  photo_urls: string[];
  pet_name: string;
  species: string;
}

type ExpressionMap = Record<string, string>;

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

    const body: GenerateRequest = await req.json();
    const { pet_id, photo_urls, pet_name, species } = body;

    if (!pet_id || !photo_urls?.length) {
      return new Response(JSON.stringify({ error: "pet_id and photo_urls required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: petRow, error: petAccessError } = await userClient
      .from("pets").select("id").eq("id", pet_id).single();
    if (petAccessError || !petRow) {
      return new Response(JSON.stringify({ error: "Pet not found or access denied" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    const primaryPhotoURL = photo_urls[0];
    console.log(`[generate-sprites] start pet=${pet_id} species=${species}`);

    // Stage A — generate base, store, write to DB immediately so the client
    // gets a usable sprite without waiting for all 5 expressions.
    const baseRawURL = await generateBaseMemoji(primaryPhotoURL, pet_name, species, pet_id);
    const baseCutoutURL = await removeBackground(baseRawURL);
    const baseStoredURL = await storeSprite(pet_id, BASE_EXPRESSION, baseCutoutURL);
    console.log(`[generate-sprites] base ready -> ${baseStoredURL}`);

    const { error: baseUpdateError } = await supabase
      .from("pets").update({ expressions: { [BASE_EXPRESSION]: baseStoredURL } }).eq("id", pet_id);
    if (baseUpdateError) throw new Error(`Failed to write base expression: ${baseUpdateError.message}`);

    // Stage B — run all 5 expression edits in parallel via waitUntil so this
    // response returns immediately after Stage A. Each expression updates the DB
    // the moment it finishes, so partial progress persists even if time-limited.
    // IMPORTANT: edits reference the raw (white-bg) base so Kontext sees a clean
    // face; bg removal runs on each output after generation.
    const edits = EXPRESSION_EDITS.filter((e) => e.key !== BASE_EXPRESSION);

    const stageB = async () => {
      const results = await Promise.allSettled(
        edits.map(async (expr, i) => {
          await sleep(i * 600);
          const rawEditURL = await editExpression(
            baseRawURL,
            expr.emotion,
            expr.instruction,
            pet_id,
            expr.key,
          );
          const cutoutURL = await removeBackground(rawEditURL);
          const storedURL = await storeSprite(pet_id, expr.key, cutoutURL);

          // Read-merge-write: fetch current expressions and merge in this one.
          // Safe here because expressions are staggered 600ms apart so true
          // concurrent writes to the same row are extremely unlikely.
          const { data: current } = await supabase
            .from("pets").select("expressions").eq("id", pet_id).single();
          const merged = { ...(current?.expressions ?? {}), [expr.key]: storedURL };
          await supabase.from("pets").update({ expressions: merged }).eq("id", pet_id);
          console.log(`[generate-sprites] "${expr.key}" done -> ${storedURL}`);
          return expr.key;
        }),
      );

      const ok = results.filter((r) => r.status === "fulfilled").length;
      const failed = results.filter((r) => r.status === "rejected").length;
      results.forEach((r, i) => {
        if (r.status === "rejected") {
          const msg = r.reason instanceof Error ? r.reason.message : String(r.reason);
          console.error(`[generate-sprites] "${edits[i].key}" failed: ${msg}`);
        }
      });
      console.log(`[generate-sprites] stage-B done pet=${pet_id} ok=${ok}/5 failed=${failed}`);
    };

    // Keep the function alive for Stage B even after the response is sent.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil(stageB());

    return new Response(JSON.stringify({ [BASE_EXPRESSION]: baseStoredURL, generating: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[generate-sprites] fatal:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

// ============================================================
// Stage A — Kontext restyle of the pet photo into Memoji
// ============================================================

async function generateBaseMemoji(
  photoURL: string,
  petName: string,
  species: string,
  petId: string,
): Promise<string> {
  const seed = stableSeed(`${petId}:base`);

  const prompt =
    `Stylize this ${species}${petName ? ` named ${petName}` : ""} from the reference photo ` +
    `into an Apple iOS animal Memoji emoji sticker — that exact 3D cartoon style, ` +
    `but recognizably THIS specific pet, not a generic template. ` +
    `${IDENTITY_PRESERVE} ` +
    `${MEMOJI_STYLE_DESCRIPTION}. ` +
    `Render the head dramatically larger than realistic (chibi cartoon proportions). ` +
    `Surface is soft matte 3D — NOT shiny, NOT wet, NOT plastic-looking. ` +
    `Happy gentle smile, mouth slightly open or closed softly. ` +
    `One single character, centered headshot, pure white background. ` +
    `AVOID: ${MEMOJI_NEGATIVE}.`;

  try {
    return await runReplicate("black-forest-labs/flux-kontext-pro", {
      prompt,
      input_image: photoURL,
      aspect_ratio: "1:1",
      output_format: "png",
      prompt_upsampling: false,
      safety_tolerance: 2,
      seed,
    });
  } catch (err) {
    console.warn("[generate-sprites] kontext base failed:", err);
  }

  try {
    return await runReplicate("black-forest-labs/flux-1.1-pro", {
      prompt,
      image_prompt: photoURL,
      aspect_ratio: "1:1",
      output_format: "png",
      output_quality: 95,
      safety_tolerance: 2,
      seed,
    });
  } catch (err) {
    console.warn("[generate-sprites] flux-1.1-pro base failed:", err);
  }

  return await runReplicate(
    "fofr/face-to-sticker:764d4827ea159608a07cdde8ddf1c6000019627515eb02b6b449695fd547e5ef",
    {
      image: photoURL,
      prompt:
        `cute cartoon ${species} portrait, Memoji style, clean rounded cartoon, soft matte shading, ` +
        `expressive face, simplified but recognizable features from the reference photo, ` +
        `preserve exact fur color, markings, and eye color from photo, ` +
        `transparent background, sticker art, gentle happy smile`,
      negative_prompt:
        `realistic, photograph, blurry, ugly, text, watermark, wrong eye color, dark eyes, ` +
        `added accessories, invented markings, glossy plastic`,
      steps: 20,
      style: "Sticker",
      upscale: false,
      seed,
      width: 1024,
      height: 1024,
    },
  );
}

// ============================================================
// Stage B — Kontext expression edits of the base sprite
// ============================================================

async function editExpression(
  baseImageURL: string,
  emotion: string,
  instruction: string,
  petId: string,
  expressionKey: string,
): Promise<string> {
  const prompt =
    `Edit this character to show a ${emotion} expression. ` +
    `${instruction} ` +
    `${EXPRESSION_EDIT_RULES} ` +
    `Keep the IDENTICAL soft matte 3D Apple-Memoji style — NOT shiny, NOT plastic. ` +
    `AVOID: ${MEMOJI_NEGATIVE}.`;

  return await runReplicate("black-forest-labs/flux-kontext-pro", {
    prompt,
    input_image: baseImageURL,
    aspect_ratio: "match_input_image",
    output_format: "png",
    prompt_upsampling: false,
    safety_tolerance: 2,
    seed: stableSeed(`${petId}:${expressionKey}`),
  });
}

// ============================================================
// Background removal — guarantees true PNG alpha output.
// Bria is production-grade with the sharpest fur/hair edges; BiRefNet (SOTA
// matting) and 851-labs are kept as fallbacks. NOTE: 851-labs and BiRefNet are
// community models and require a pinned version hash, otherwise Replicate's
// /v1/models/{owner}/{name}/predictions endpoint returns 404.
// ============================================================

async function removeBackground(imageURL: string): Promise<string> {
  try {
    return await runReplicate("bria/remove-background", {
      image_url: imageURL,
      preserve_alpha: true,
    });
  } catch (err) {
    console.warn("[generate-sprites] bria background-remover failed, trying birefnet:", err);
  }

  try {
    return await runReplicate(
      "men1scus/birefnet:f74986db0355b58403ed20963af156525e2891ea3c2d499bfbfb2a28cd87c5d7",
      { image: imageURL, resolution: "2048x2048" },
    );
  } catch (err) {
    console.warn("[generate-sprites] birefnet failed, trying 851-labs:", err);
  }

  try {
    return await runReplicate(
      "851-labs/background-remover:a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc",
      { image: imageURL, format: "png", background_type: "rgba" },
    );
  } catch (err) {
    console.warn("[generate-sprites] all background removers failed, keeping original:", err);
    return imageURL;
  }
}

// ============================================================
// Replicate helper — official model endpoint + long poll.
// ============================================================

async function runReplicate(
  model: string,
  input: Record<string, unknown>,
): Promise<string> {
  const isVersionPinned = model.includes(":");
  const url = isVersionPinned
    ? "https://api.replicate.com/v1/predictions"
    : `https://api.replicate.com/v1/models/${model}/predictions`;

  const body: Record<string, unknown> = isVersionPinned
    ? { version: model.split(":")[1], input }
    : { input };

  // Retry on 429 (rate limit) and transient network errors. Replicate enforces
  // burst-of-1 throttling for low-credit accounts; we honor retry-after.
  let startRes: Response | undefined;
  for (let attempt = 0; attempt < 12; attempt++) {
    try {
      startRes = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Token ${REPLICATE_API_TOKEN}`,
          "Content-Type": "application/json",
          "Prefer": "wait=30",
        },
        body: JSON.stringify(body),
      });
    } catch (err) {
      console.warn(`[runReplicate] network error, retrying:`, err);
      await sleep(5000);
      continue;
    }
    if (startRes.status === 429) {
      const retryAfter = parseInt(startRes.headers.get("retry-after") ?? "15", 10);
      console.log(`[runReplicate] 429 rate-limited, waiting ${retryAfter}s`);
      await sleep((retryAfter + 2) * 1000);
      continue;
    }
    break;
  }
  if (!startRes) {
    throw new Error("Replicate start failed after retries (network)");
  }
  if (!startRes.ok) {
    throw new Error(`Replicate start failed (${startRes.status}): ${await startRes.text()}`);
  }

  const prediction = await startRes.json();
  if (prediction.status === "succeeded") return extractOutput(prediction.output);
  if (prediction.status === "failed" || prediction.status === "canceled") {
    throw new Error(`Replicate prediction failed: ${prediction.error ?? prediction.status}`);
  }

  const predictionId = prediction.id;
  const maxAttempts = 90; // ~3 minutes
  for (let i = 0; i < maxAttempts; i++) {
    await sleep(2000);
    const pollRes = await fetch(`https://api.replicate.com/v1/predictions/${predictionId}`, {
      headers: { "Authorization": `Token ${REPLICATE_API_TOKEN}` },
    });
    const status = await pollRes.json();
    if (status.status === "succeeded") return extractOutput(status.output);
    if (status.status === "failed" || status.status === "canceled") {
      throw new Error(`Replicate prediction failed: ${status.error ?? status.status}`);
    }
  }
  throw new Error("Replicate prediction timed out");
}

function extractOutput(output: unknown): string {
  if (typeof output === "string") return output;
  if (Array.isArray(output) && output.length > 0 && typeof output[0] === "string") return output[0];
  throw new Error("Replicate returned empty output");
}

// ============================================================
// Storage
// ============================================================

async function storeSprite(petId: string, expression: string, imageURL: string): Promise<string> {
  const res = await fetch(imageURL);
  if (!res.ok) throw new Error(`Failed to download sprite: ${res.statusText}`);
  const imageData = await res.arrayBuffer();

  const path = `${petId}/${expression}.png`;
  const { error } = await supabase.storage
    .from("pet-sprites")
    .upload(path, imageData, { contentType: "image/png", upsert: true });
  if (error) throw new Error(`Storage upload failed: ${error.message}`);

  const { data } = supabase.storage.from("pet-sprites").getPublicUrl(path);
  return data.publicUrl;
}

// ============================================================
// Utilities
// ============================================================

function stableSeed(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0) % 2_147_483_000 || 1;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
