-- Fix for infinite recursion in RLS policies
-- The previous policies caused a 500 error because they recursively queried the same tables.
-- We fix this by using a "security definer" function that bypasses RLS for the check.

-- 1. Create a security definer function to check participation
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

-- 2. Drop existing problematic policies
drop policy if exists "Users can view their own conversations" on public.conversations;
drop policy if exists "Users can view participants of their conversations" on public.conversation_participants;
drop policy if exists "Users can view messages in their conversations" on public.messages;
drop policy if exists "Users can insert messages in their conversations" on public.messages;

-- 3. Re-create policies using the helper function

-- Conversations
create policy "Users can view their own conversations" on public.conversations
  for select using (
    is_participant(id)
  );

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
