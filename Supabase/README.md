# Petmoji — Supabase Setup

## 1. Create Supabase Project

Go to [supabase.com](https://supabase.com) and create a new project.

## 2. Apply Database Schema

In the Supabase SQL editor, run the contents of:

```
migrations/001_initial_schema.sql
```

This creates:
- `pets` table with RLS
- `messages` table with RLS
- Storage buckets (`pet-photos`, `pet-sprites`)

## 3. Create Storage Buckets (UI Method)

If storage creation via SQL doesn't work, create them manually:

1. Go to **Storage** in your Supabase dashboard
2. Create bucket `pet-photos` — **Private**, 10MB limit, allow JPEG/PNG/WEBP/HEIC
3. Create bucket `pet-sprites` — **Public**, 5MB limit, allow PNG/WEBP

## 4. Deploy Edge Functions

Install the Supabase CLI and run:

```bash
supabase functions deploy generate-sprites
supabase functions deploy generate-messages
supabase functions deploy location-event
```

Set required secrets:

```bash
supabase secrets set REPLICATE_API_TOKEN=r8_...
supabase secrets set CLAUDE_API_KEY=sk-ant-...
supabase secrets set OPENWEATHER_API_KEY=...
supabase secrets set APNS_KEY_ID=...         # optional
supabase secrets set APNS_TEAM_ID=...        # optional
supabase secrets set APNS_PRIVATE_KEY=...    # optional
```

## 5. Set Up Cron for generate-messages

In Supabase dashboard → **Database** → **Cron Jobs** (pg_cron), or use the Edge Functions scheduled invocations:

```sql
-- Run every 2 hours between 7am and 11pm
select cron.schedule(
  'generate-pet-messages',
  '0 7,9,12,15,17,19,21,23 * * *',
  $$
    select net.http_post(
      url := 'https://YOUR_PROJECT.supabase.co/functions/v1/generate-messages',
      headers := '{"Authorization": "Bearer SERVICE_ROLE_KEY"}'::jsonb
    );
  $$
);
```

## 6. Configure iOS App

In `SupabaseService.swift`, update:

```swift
private let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
private let supabaseKey = "YOUR_ANON_KEY"
```

Or set environment variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

In `ClaudeService.swift`:
- `CLAUDE_API_KEY` (for on-device chat — consider proxying through your backend instead)

## Architecture Notes

- **generate-sprites**: Called once during onboarding. Generates 6 expression variants via Replicate API and stores in `pet-sprites` bucket.
- **generate-messages**: Cron function. Runs on schedule, generates Claude messages, stores in `messages` table.
- **location-event**: Called by iOS app on geofence trigger. Generates priority message immediately.
- Widget reads from Supabase via shared `UserDefaults` (App Group) populated by main app on message receipt.
