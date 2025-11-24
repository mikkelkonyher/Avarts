-- Migration: Add comment reactions table
-- Run this in your Supabase SQL Editor

-- Create the comment_reactions table
CREATE TABLE IF NOT EXISTS comment_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES activity_comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure a user can only react once per comment with the same emoji
  UNIQUE(comment_id, user_id, emoji)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_comment_reactions_comment_id 
  ON comment_reactions(comment_id);

CREATE INDEX IF NOT EXISTS idx_comment_reactions_user_id 
  ON comment_reactions(user_id);

CREATE INDEX IF NOT EXISTS idx_comment_reactions_emoji 
  ON comment_reactions(emoji);

-- Enable Row Level Security (RLS)
ALTER TABLE comment_reactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all reactions
CREATE POLICY "Users can view all reactions"
  ON comment_reactions
  FOR SELECT
  USING (true);

-- Policy: Users can insert their own reactions
CREATE POLICY "Users can insert their own reactions"
  ON comment_reactions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own reactions
CREATE POLICY "Users can delete their own reactions"
  ON comment_reactions
  FOR DELETE
  USING (auth.uid() = user_id);

-- Policy: Users cannot update reactions (only add/remove)
-- No UPDATE policy needed since we don't allow updates

-- Optional: Add a function to automatically clean up orphaned reactions
-- (This is handled by CASCADE, but you can add this for extra safety)
CREATE OR REPLACE FUNCTION cleanup_orphaned_reactions()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM comment_reactions 
  WHERE comment_id NOT IN (SELECT id FROM activity_comments);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Optional: Add a trigger to clean up reactions when comments are deleted
-- (CASCADE should handle this, but this is an extra safety measure)
-- CREATE TRIGGER cleanup_reactions_trigger
-- AFTER DELETE ON activity_comments
-- FOR EACH ROW
-- EXECUTE FUNCTION cleanup_orphaned_reactions();

