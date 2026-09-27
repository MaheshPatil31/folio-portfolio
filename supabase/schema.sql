-- Run once in the Supabase SQL editor for your project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,40}$'),
  name text not null default '',
  headline text not null default '',
  bio text not null default '',
  location text not null default '',
  avatar text not null default '',
  email text not null default '',
  email_public boolean not null default false,
  availability boolean not null default false,
  skills text[] not null default '{}',
  socials jsonb not null default '[]',
  projects jsonb not null default '[]',
  experience text not null default '',
  education text not null default '',
  published boolean not null default false,
  updated_at timestamptz not null default now()
);

-- Migrate the earlier schema's default-true profiles to private once. The old column default
-- distinguishes that schema, so re-running this script will not unpublish new user choices.
do $$
declare old_default text;
begin
  select pg_get_expr(d.adbin, d.adrelid) into old_default
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum
  where n.nspname = 'public' and c.relname = 'profiles' and a.attname = 'published' and not a.attisdropped;
  if old_default = 'true' then update public.profiles set published = false; end if;
end $$;

-- Keep new accounts private until their owner chooses to publish.
alter table public.profiles alter column published set default false;
update public.profiles set published = false where length(trim(name)) = 0;
create index if not exists profiles_public_updated_idx on public.profiles (updated_at desc) where published = true;

alter table public.profiles enable row level security;
drop policy if exists "Anyone can read published portfolios" on public.profiles;
drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users create their own profile" on public.profiles;
drop policy if exists "Users update their own profile" on public.profiles;
drop policy if exists "Users delete their own profile" on public.profiles;
create policy "Users can read their own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users create their own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "Users update their own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Users delete their own profile" on public.profiles for delete using (auth.uid() = id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('portfolio-images', 'portfolio-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do nothing;
drop policy if exists "Portfolio images are publicly readable" on storage.objects;
drop policy if exists "Users upload portfolio images to their folder" on storage.objects;
drop policy if exists "Users update portfolio images in their folder" on storage.objects;
drop policy if exists "Users delete portfolio images in their folder" on storage.objects;
create policy "Portfolio images are publicly readable" on storage.objects for select using (bucket_id = 'portfolio-images');
create policy "Users upload portfolio images to their folder" on storage.objects for insert with check (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users update portfolio images in their folder" on storage.objects for update using (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users delete portfolio images in their folder" on storage.objects for delete using (bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = auth.uid()::text);


-- Public reads go through this function so private account fields and draft projects never leave the database.
create or replace function public.get_public_portfolio(requested_slug text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'slug', p.slug, 'name', p.name, 'headline', p.headline, 'bio', p.bio,
    'location', p.location, 'avatar', p.avatar,
    'email', case when p.email_public then p.email else '' end,
    'emailPublic', p.email_public, 'availability', p.availability, 'published', p.published,
    'skills', p.skills, 'socials', p.socials, 'experience', p.experience, 'education', p.education,
    'projects', coalesce((select jsonb_agg(project_item) from jsonb_array_elements(p.projects) as items(project_item) where project_item->>'published' = 'true'), '[]'::jsonb)
  ) from public.profiles p where p.slug = requested_slug and p.published = true limit 1;
$$;
revoke all on function public.get_public_portfolio(text) from public;
grant execute on function public.get_public_portfolio(text) to anon, authenticated;

-- Search returns only public discovery fields for portfolios their owners published.
create or replace function public.search_public_profiles(search_term text default '')
returns table(slug text, name text, headline text, avatar text, location text, skills text[], project_count integer)
language sql stable security definer set search_path = '' as $$
  select p.slug, p.name, p.headline, p.avatar, p.location, p.skills,
    (select count(*)::integer from jsonb_array_elements(p.projects) as items(project_item) where project_item->>'published' = 'true')
  from public.profiles p
  where p.published = true and length(trim(p.name)) > 0
    and (coalesce(trim(search_term), '') = '' or lower(concat_ws(' ', p.name, p.headline, p.location, array_to_string(p.skills, ' '))) like '%' || lower(trim(search_term)) || '%')
  order by p.updated_at desc limit 60;
$$;
revoke all on function public.search_public_profiles(text) from public;
grant execute on function public.search_public_profiles(text) to anon, authenticated;

-- Account deletion is performed inside Postgres so the app never needs a service role key.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from storage.objects where bucket_id = 'portfolio-images' and (storage.foldername(name))[1] = auth.uid()::text;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
-- Optional: scaffold a profile row for new accounts. The first app save fills in the editor fields.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, slug, name, email)
  values (new.id, left(lower(regexp_replace(split_part(new.email, '@', 1), '[^a-zA-Z0-9-]', '-', 'g')), 30) || '-' || left(new.id::text, 6), coalesce(new.raw_user_meta_data->>'name',''), coalesce(new.email,''));
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
