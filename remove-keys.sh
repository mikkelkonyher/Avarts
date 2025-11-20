#!/bin/bash

# Script to remove Supabase keys from Git history
# WARNING: This rewrites Git history. Make sure to backup first!

set -e

echo "⚠️  WARNING: This will rewrite Git history!"
echo "Make sure you have a backup and have coordinated with your team."
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# The keys to remove
OLD_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1eHN1Y2V0eW55a2NhcGxnc2lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1OTI4OTEsImV4cCI6MjA3OTE2ODg5MX0.JTMcayB53lcWlKUrT3x4oNEUSn5ts6iPjcLO40a6nCM"
OLD_URL="https://uuxsucetynykcaplgsir.supabase.co"

echo "Removing keys from Git history..."

# Use git filter-branch to replace keys in README.md throughout history
git filter-branch --force --tree-filter \
  "if [ -f Flutter_Avartsapp/README.md ]; then \
    sed -i '' 's|$OLD_KEY|YOUR_SUPABASE_ANON_KEY|g; s|$OLD_URL|YOUR_SUPABASE_URL|g' Flutter_Avartsapp/README.md 2>/dev/null || \
    sed -i 's|$OLD_KEY|YOUR_SUPABASE_ANON_KEY|g; s|$OLD_URL|YOUR_SUPABASE_URL|g' Flutter_Avartsapp/README.md 2>/dev/null || true; \
  fi" \
  --prune-empty --tag-name-filter cat -- --all

echo ""
echo "✅ Keys removed from Git history!"
echo ""
echo "Next steps:"
echo "1. Review the changes: git log --all -- Flutter_Avartsapp/README.md"
echo "2. Force push to GitHub: git push --force --all"
echo "3. ROTATE YOUR SUPABASE KEYS immediately in the Supabase dashboard!"
echo "4. Update your .env file with new keys"

