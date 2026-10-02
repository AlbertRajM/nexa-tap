-- =============================================================
--  NEXA TAP — database setup
--  Paste this whole file into Supabase → SQL Editor → New query → Run.
--  Safe to run more than once.
-- =============================================================

create extension if not exists pgcrypto;

-- ---------- PROFILES (one row per user) ----------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text not null default '',
  email         text,
  username      text unique,
  referral_code text unique,
  referred_by   text,
  default_card  text not null default 'business' check (default_card in ('personal','business')),
  active        boolean not null default true,
  views         integer not null default 0,
  created_at    timestamptz not null default now()
);

-- ---------- CARDS (personal + business per user) ----------
create table if not exists public.cards (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       text not null check (type in ('personal','business')),
  enabled    boolean not null default true,
  design     text not null default 'graphite',
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, type)
);

-- ---------- ORDERS ----------
create table if not exists public.orders (
  id           uuid primary key default gen_random_uuid(),
  order_no     text not null unique default ('NX' || to_char(now(),'YYMMDD') || lpad((floor(random()*10000))::int::text, 4, '0')),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  card_type    text not null default 'business',
  design       text not null default 'graphite',
  name_on_card text not null,
  quantity     integer not null default 1 check (quantity between 1 and 50),
  phone        text not null,
  address      text not null,
  city         text not null,
  pincode      text not null,
  amount       integer not null default 0,
  status       text not null default 'placed'
               check (status in ('placed','confirmed','printing','quality_check','shipped','delivered','cancelled')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------- SECURITY (each user sees only their own data) ----------
alter table public.profiles enable row level security;
alter table public.cards    enable row level security;
alter table public.orders   enable row level security;

drop policy if exists "own profile read"   on public.profiles;
drop policy if exists "own profile update" on public.profiles;
create policy "own profile read"   on public.profiles for select using (auth.uid() = id);
create policy "own profile update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own cards all" on public.cards;
create policy "own cards all" on public.cards for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own orders read"   on public.orders;
drop policy if exists "own orders insert" on public.orders;
create policy "own orders read"   on public.orders for select using (auth.uid() = user_id);
create policy "own orders insert" on public.orders for insert with check (auth.uid() = user_id and status = 'placed');

-- ---------- NEW USER → create profile + 2 cards automatically ----------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  nm    text := coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1));
  base  text := lower(regexp_replace(nm, '[^a-zA-Z0-9]', '', 'g'));
  code  text;
  uname text;
  ref   text := upper(trim(coalesce(new.raw_user_meta_data->>'referred_by', '')));
begin
  if base = '' then base := 'user'; end if;
  loop
    uname := left(base, 16) || lpad((floor(random()*10000))::int::text, 4, '0');
    exit when not exists (select 1 from public.profiles where username = uname);
  end loop;
  loop
    code := upper(left(rpad(base, 4, 'X'), 4)) || lpad((floor(random()*10000))::int::text, 4, '0');
    exit when not exists (select 1 from public.profiles where referral_code = code);
  end loop;
  if ref <> '' and not exists (select 1 from public.profiles where referral_code = ref) then
    ref := '';
  end if;

  insert into public.profiles (id, full_name, email, username, referral_code, referred_by)
  values (new.id, nm, new.email, uname, code, nullif(ref, ''));

  insert into public.cards (user_id, type, enabled, data)
  values (new.id, 'business', true,  jsonb_build_object('name', nm, 'email', new.email)),
         (new.id, 'personal', false, jsonb_build_object('name', nm, 'email', new.email));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- REFERRAL STATS for the signed-in user ----------
create or replace function public.referral_stats()
returns json language sql security definer set search_path = public stable as $$
  with me as (select referral_code from public.profiles where id = auth.uid()),
  friends as (
    select p.full_name, p.created_at,
           exists (select 1 from public.orders o where o.user_id = p.id and o.status <> 'cancelled') as ordered
    from public.profiles p, me
    where p.referred_by = me.referral_code
  )
  select json_build_object(
    'joined',  (select count(*) from friends),
    'ordered', (select count(*) from friends where ordered),
    'list',    coalesce((select json_agg(json_build_object('name', full_name, 'joined_at', created_at, 'ordered', ordered)
                                  order by created_at desc) from friends), '[]'::json)
  );
$$;

-- ---------- PUBLIC PROFILE (used by the tap / QR web page) ----------
create or replace function public.get_public_profile(uname text, card_type text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  p public.profiles;
  c public.cards;
begin
  select * into p from public.profiles where username = lower(uname) and active;
  if not found then return null; end if;

  select * into c from public.cards
   where user_id = p.id and enabled
     and type = coalesce(card_type, p.default_card)
   limit 1;
  if not found then
    select * into c from public.cards where user_id = p.id and enabled limit 1;
  end if;
  if not found then return null; end if;

  update public.profiles set views = views + 1 where id = p.id;
  return json_build_object('username', p.username, 'type', c.type, 'design', c.design, 'data', c.data);
end $$;

grant execute on function public.get_public_profile(text, text) to anon, authenticated;
grant execute on function public.referral_stats() to authenticated;

-- ---------- PHOTO STORAGE (public bucket "media", users write only their own folder) ----------
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do update set public = true;

drop policy if exists "media public read" on storage.objects;
drop policy if exists "media own insert"  on storage.objects;
drop policy if exists "media own update"  on storage.objects;
drop policy if exists "media own delete"  on storage.objects;
create policy "media public read" on storage.objects for select using (bucket_id = 'media');
create policy "media own insert"  on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media own update"  on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media own delete"  on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
