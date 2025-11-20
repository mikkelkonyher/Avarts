# Instructions to Remove Supabase Keys from Git History

## ⚠️ IMPORTANT: Read this before proceeding

The Supabase keys were accidentally committed to the README.md file. Follow these steps to remove them from Git history.

## Step 1: Backup your repository
```bash
cd /Users/mikkelkonyher/Documents/GitHub/Avarts
git clone . ../Avarts-backup
```

## Step 2: Remove keys from Git history using git filter-repo (Recommended)

### Install git-filter-repo (if not installed):
```bash
# macOS
brew install git-filter-repo

# Or using pip
pip install git-filter-repo
```

### Remove the keys from history:
```bash
cd /Users/mikkelkonyher/Documents/GitHub/Avarts

# Remove the specific keys from README.md in all commits
git filter-repo --path Flutter_Avartsapp/README.md \
  --replace-text <(echo 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1eHN1Y2V0eW55a2NhcGxnc2lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1OTI4OTEsImV4cCI6MjA3OTE2ODg5MX0.JTMcayB53lcWlKUrT3x4oNEUSn5ts6iPjcLO40a6nCM==>YOUR_SUPABASE_ANON_KEY') \
  --replace-text <(echo 'https://uuxsucetynykcaplgsir.supabase.co==>YOUR_SUPABASE_URL')
```

## Alternative: Using BFG Repo-Cleaner (Easier)

### Download BFG:
```bash
# Download from https://rtyley.github.io/bfg-repo-cleaner/
# Or use Homebrew:
brew install bfg
```

### Create a replacements file:
```bash
cd /Users/mikkelkonyher/Documents/GitHub/Avarts
cat > keys-replacements.txt << EOF
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1eHN1Y2V0eW55a2NhcGxnc2lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1OTI4OTEsImV4cCI6MjA3OTE2ODg5MX0.JTMcayB53lcWlKUrT3x4oNEUSn5ts6iPjcLO40a6nCM==>YOUR_SUPABASE_ANON_KEY
https://uuxsucetynykcaplgsir.supabase.co==>YOUR_SUPABASE_URL
EOF
```

### Run BFG:
```bash
# Clone a fresh copy (BFG needs a bare repo)
git clone --mirror . ../Avarts-mirror.git
cd ../Avarts-mirror.git

# Run BFG
bfg --replace-text ../Avarts/keys-replacements.txt

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Push back
cd ../Avarts
git remote set-url origin <your-github-url>
git push --force --all
```

## Step 3: Force push to GitHub (⚠️ DANGEROUS - Coordinate with team)

```bash
cd /Users/mikkelkonyher/Documents/GitHub/Avarts

# WARNING: This rewrites history. Make sure all team members are aware!
git push --force --all
git push --force --tags
```

## Step 4: Rotate your Supabase keys (CRITICAL!)

Since the keys were exposed in Git history, you MUST rotate them:

1. Go to your Supabase Dashboard
2. Navigate to Settings > API
3. Generate new keys
4. Update your `.env` file with the new keys
5. Update any deployed applications

## Step 5: Verify keys are removed

```bash
# Check that keys are no longer in history
git log --all --source --full-history -p -- Flutter_Avartsapp/README.md | grep -i "eyJ\|uuxsucetynykcaplgsir"
```

If this returns nothing, the keys have been successfully removed.

## Notes:

- **This rewrites Git history** - anyone who has cloned the repo will need to re-clone
- **Coordinate with your team** before force pushing
- **Rotate the exposed keys immediately** - they are compromised
- Consider using environment variables or secrets management for future projects

