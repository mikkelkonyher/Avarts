-- 1. Enable RLS on profiles (if not already enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Allow everyone to read profiles (Essential for search to work)
CREATE POLICY "Public profiles are viewable by everyone"
ON public.profiles FOR SELECT
USING ( true );

-- 3. Add missing columns to match the App's UserProfile model
-- The app expects 'display_name' and 'bio' for a richer experience.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio text;

-- 4. Create the follows table
CREATE TABLE IF NOT EXISTS public.follows (
    follower_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (follower_id, following_id)
);

-- 5. Enable RLS on follows
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for follows

-- Allow everyone to see who follows whom (needed to show "Following" status)
CREATE POLICY "Follows are viewable by everyone"
ON public.follows FOR SELECT
USING ( true );

-- Allow authenticated users to follow others
CREATE POLICY "Users can follow others"
ON public.follows FOR INSERT
WITH CHECK ( auth.uid() = follower_id );

-- Allow authenticated users to unfollow
CREATE POLICY "Users can unfollow"
ON public.follows FOR DELETE
USING ( auth.uid() = follower_id );

-- 7. (Optional) Backfill display_name from user_name if it's empty
UPDATE public.profiles 
SET display_name = user_name 
WHERE display_name IS NULL;
