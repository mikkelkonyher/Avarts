-- Create conversations table
create table public.conversations (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint conversations_pkey primary key (id)
);

-- Create conversation_participants table
create table public.conversation_participants (
  conversation_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint conversation_participants_pkey primary key (conversation_id, user_id),
  constraint conversation_participants_conversation_id_fkey foreign key (conversation_id) references conversations (id) on delete cascade,
  constraint conversation_participants_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);

-- Create messages table
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

-- Enable RLS
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;

-- Helper function to check participation (Security Definer to avoid RLS recursion)
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

-- RLS Policies for conversations
create policy "Users can view their own conversations" on public.conversations
  for select using (
    is_participant(id)
  );
  
-- Users can insert conversations (anyone authenticated)
create policy "Users can create conversations" on public.conversations
  for insert with check (auth.role() = 'authenticated');

-- Users can update conversations they are part of (e.g. updated_at)
create policy "Users can update their conversations" on public.conversations
  for update using (
    is_participant(id)
  );

-- RLS Policies for conversation_participants
create policy "Users can view participants of their conversations" on public.conversation_participants
  for select using (
    is_participant(conversation_id)
  );

-- Users can insert participants (simplified: allow authenticated users)
create policy "Users can insert participants" on public.conversation_participants
  for insert with check (auth.role() = 'authenticated');

-- RLS Policies for messages
create policy "Users can view messages in their conversations" on public.messages
  for select using (
    is_participant(conversation_id)
  );

create policy "Users can insert messages in their conversations" on public.messages
  for insert with check (
    auth.uid() = sender_id and
    is_participant(conversation_id)
  );

-- Realtime
alter publication supabase_realtime add table public.messages;

-- Helper function to find existing conversation
create or replace function find_conversation_with_user(other_user_id uuid)
returns uuid
language plpgsql
security definer
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
