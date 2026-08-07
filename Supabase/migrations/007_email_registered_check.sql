-- ============================================================
-- Sign-up: check if email already has an auth user
-- (OTP with shouldCreateUser: true does not reject existing emails)
-- ============================================================

create or replace function public.is_email_registered(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from auth.users
    where lower(email) = lower(trim(p_email))
  );
$$;

revoke all on function public.is_email_registered(text) from public;
grant execute on function public.is_email_registered(text) to anon, authenticated;
