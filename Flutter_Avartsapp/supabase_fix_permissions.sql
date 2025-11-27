-- Fix for 403 Forbidden error
-- This error occurs when the 'authenticated' role does not have permission to access the tables or functions.

-- 1. Grant access to tables
grant select, insert, update, delete on table public.conversations to authenticated;
grant select, insert, update, delete on table public.conversation_participants to authenticated;
grant select, insert, update, delete on table public.messages to authenticated;

-- 2. Grant access to functions
grant execute on function public.is_participant(uuid) to authenticated;
grant execute on function public.find_conversation_with_user(uuid) to authenticated;

-- 3. Ensure sequences (if any, though we use UUIDs) are accessible
-- (Not needed for UUIDs with gen_random_uuid())

-- 4. Just in case, grant to service_role as well (usually default, but good to be sure)
grant select, insert, update, delete on table public.conversations to service_role;
grant select, insert, update, delete on table public.conversation_participants to service_role;
grant select, insert, update, delete on table public.messages to service_role;
grant execute on function public.is_participant(uuid) to service_role;
grant execute on function public.find_conversation_with_user(uuid) to service_role;
