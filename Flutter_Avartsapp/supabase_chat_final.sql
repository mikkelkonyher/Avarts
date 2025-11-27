-- FINAL FIX: Reset and Re-create Chat System
-- This script drops existing chat tables and functions to ensure a clean slate.
-- It sets up the schema, RLS, permissions, and helper functions correctly.

-- 1. Drop existing objects (Order matters due to dependencies)
drop policy if exists "Users can view their own conversations" on public.conversations;
drop policy if exists "Users can create conversations" on public.conversations;
drop policy if exists "Users can update their conversations" on public.conversations;

drop policy if exists "Users can view participants of their conversations" on public.conversation_participants;
drop policy if exists "Users can insert participants" on public.conversation_participants;

drop policy if exists "Users can view messages in their conversations" on public.messages;
drop policy if exists "Users can insert messages in their conversations" on public.messages;

drop function if exists public.is_participant(uuid);
drop function if exists public.find_conversation_with_user(uuid);
drop function if exists public.create_new_conversation(uuid);

drop table if exists public.messages;
drop table if exists public.conversation_participants;
drop table if exists public.conversations;

-- 2. Create Tables

-- Conversations
create table public.conversations (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint conversations_pkey primary key (id)
);

-- Conversation Participants
create table public.conversation_participants (
  conversation_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint conversation_participants_pkey primary key (conversation_id, user_id),
  constraint conversation_participants_conversation_id_fkey foreign key (conversation_id) references conversations (id) on delete cascade,
  constraint conversation_participants_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);

-- Messages
create table public.messages (
  id uuid not null default gen_random_uuid (),
  conversation_id uuid not null,
  sender_id uuid not null,
  content text not null,
  created_at timestamp with time zone not null default now(),
  constraint messages_pkey primary key (id),
  constraint messages_conversation_id_fkey foreign key (conversation_id) references conversations (id) on delete cascade,
  constraint messages_sender_id_fkey foreign key (sender_id) references auth.users (id) on delete cascade
);

-- 3. Enable RLS
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;

-- 4. Helper Functions (Security Definer to bypass RLS recursion)

-- Check participation
create or replace function public.is_participant(conversation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from conversation_participants
    where conversation_id = $1
    and user_id = auth.uid()
  );
$$;

-- Find existing conversation
create or replace function public.find_conversation_with_user(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  conv_id uuid;
begin
  select c1.conversation_id into conv_id
  from conversation_participants c1
  join conversation_participants c2 on c1.conversation_id = c2.conversation_id
  where c1.user_id = auth.uid()
  and c2.user_id = other_user_id
  limit 1;
  
  return conv_id;
end;
$$;

-- Create new conversation atomically
create or replace function public.create_new_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  -- Create conversation
  insert into conversations default values returning id into new_id;
  
  -- Add participants (Current user + Other user)
  insert into conversation_participants (conversation_id, user_id)
  values 
    (new_id, auth.uid()),
    (new_id, other_user_id);
    
  return new_id;
end;
$$;

-- 5. RLS Policies

-- Conversations
create policy "Users can view their own conversations" on public.conversations
  for select using (
    is_participant(id)
  );
  
-- Note: We don't need INSERT policy for conversations if we use the RPC function.
-- But for robustness, we can leave it if we want manual inserts later.
-- For now, let's rely on the RPC for creation to avoid the "Insert-Select" visibility race.

-- Conversation Participants
create policy "Users can view participants of their conversations" on public.conversation_participants
  for select using (
    is_participant(conversation_id)
  );

-- Messages
create policy "Users can view messages in their conversations" on public.messages
  for select using (
    is_participant(conversation_id)
  );

create policy "Users can insert messages in their conversations" on public.messages
  for insert with check (
    auth.uid() = sender_id and
    is_participant(conversation_id)
  );

-- 6. Permissions (Fix for 403)
grant usage on schema public to authenticated;
grant usage on schema public to service_role;

grant select, insert, update, delete on table public.conversations to authenticated;
grant select, insert, update, delete on table public.conversation_participants to authenticated;
grant select, insert, update, delete on table public.messages to authenticated;

grant execute on function public.is_participant(uuid) to authenticated;
grant execute on function public.find_conversation_with_user(uuid) to authenticated;
grant execute on function public.create_new_conversation(uuid) to authenticated;

grant select, insert, update, delete on table public.conversations to service_role;
grant select, insert, update, delete on table public.conversation_participants to service_role;
grant select, insert, update, delete on table public.messages to service_role;

-- 7. Realtime
alter publication supabase_realtime add table public.messages;
