-- ============================================================
-- Device Tokens table (for APNs push notifications)
-- ============================================================

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null default 'ios' check (platform in ('ios')),
  environment text not null default 'development' check (environment in ('development', 'production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- One token per user/device combo
  unique (user_id, token)
);

-- RLS
alter table public.device_tokens enable row level security;

create policy "Users can manage their own device tokens"
  on public.device_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Service role can read device tokens"
  on public.device_tokens
  for select
  using (auth.role() = 'service_role');

-- Index for push lookups
create index device_tokens_user_id_idx on public.device_tokens(user_id);
