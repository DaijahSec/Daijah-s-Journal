-- Run this in your Supabase project's SQL Editor.
-- If you already ran the original setup.sql, just run this file too — it only adds new things.

-- 1. Add mood and photo columns to entries
alter table entries add column if not exists mood text;
alter table entries add column if not exists image_paths text[];

-- 2. Settings table (one row per user, for theme + background customization)
create table if not exists settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  accent_theme text not null default 'honey',
  background_url text,
  updated_at timestamptz not null default now()
);

alter table settings enable row level security;

create policy "Users can view their own settings"
  on settings for select
  using (auth.uid() = user_id);

create policy "Users can insert their own settings"
  on settings for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own settings"
  on settings for update
  using (auth.uid() = user_id);

-- 3. Photo storage bucket (private — only accessible via signed URLs)
insert into storage.buckets (id, name, public)
values ('journal-photos', 'journal-photos', false)
on conflict (id) do nothing;

-- Each user can only touch files inside a folder named after their own user id
-- (the app uploads to a path like "<user_id>/<random>.jpg", so this matches that)
create policy "Users can upload their own photos"
  on storage.objects for insert
  with check (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own photos"
  on storage.objects for select
  using (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own photos"
  on storage.objects for delete
  using (
    bucket_id = 'journal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
