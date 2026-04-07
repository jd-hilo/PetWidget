-- ============================================================
-- Petmoji Initial Schema
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ============================================================
-- PETS TABLE
-- ============================================================
create table public.pets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  -- Identity
  name text not null,
  species text not null check (species in ('dog', 'cat', 'other')),

  -- Generated sprites (expression name -> URL)
  expressions jsonb not null default '{}',

  -- Personality profile
  personality_traits text[] not null default '{}',
  energy_level int not null default 5 check (energy_level between 1 and 10),
  biggest_enemy text not null default 'vacuum cleaner',
  base_mood text not null default 'chill' check (
    base_mood in ('chill', 'mildly suspicious', 'emotionally fragile', 'unimpressed')
  ),

  -- Location (coarse, for weather only)
  home_lat float,
  home_lng float,
  timezone text not null default 'America/New_York',

  created_at timestamptz not null default now()
);

-- RLS: users can only see/edit their own pets
alter table public.pets enable row level security;

create policy "Users can manage their own pets"
  on public.pets
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- MESSAGES TABLE
-- ============================================================
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,

  content text not null,
  expression text not null default 'happy' check (
    expression in ('happy', 'sleepy', 'mad', 'excited', 'misses_you', 'judging')
  ),
  trigger_type text not null check (
    trigger_type in ('scheduled', 'left_home', 'returned', 'been_gone_2h', 'been_gone_6h', 'chat_reply')
  ),

  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,

  created_at timestamptz not null default now()
);

-- Index for fetching latest messages per pet
create index messages_pet_id_sent_at_idx on public.messages(pet_id, sent_at desc);

-- RLS: messages belong to pet which belongs to user
alter table public.messages enable row level security;

create policy "Users can read their pet's messages"
  on public.messages
  for select
  using (
    exists (
      select 1 from public.pets
      where pets.id = messages.pet_id
        and pets.user_id = auth.uid()
    )
  );

create policy "Service role can manage messages"
  on public.messages
  for all
  using (auth.role() = 'service_role');

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================

-- Pet photos (original uploads)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pet-photos',
  'pet-photos',
  false,
  10485760, -- 10MB
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
);

-- Generated sprites (public — referenced by widget)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pet-sprites',
  'pet-sprites',
  true,
  5242880, -- 5MB
  array['image/png', 'image/webp']
);

-- Storage RLS
create policy "Users can upload their pet photos"
  on storage.objects for insert
  with check (
    bucket_id = 'pet-photos'
    and auth.uid() is not null
  );

create policy "Users can read their pet photos"
  on storage.objects for select
  using (
    bucket_id = 'pet-photos'
    and auth.uid() is not null
  );

create policy "Anyone can read sprites"
  on storage.objects for select
  using (bucket_id = 'pet-sprites');

create policy "Service role can manage sprites"
  on storage.objects for all
  using (auth.role() = 'service_role');
