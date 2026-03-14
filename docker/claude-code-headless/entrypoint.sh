#!/bin/bash
set -e

# Git setup — derive identity from GitHub token
gh auth setup-git
GH_USER_JSON=$(gh api user -q '{name: .name, login: .login, email: .email, id: .id}')
GH_USER_NAME=$(echo "$GH_USER_JSON" | jq -r '.name // .login')
GH_USER_EMAIL=$(echo "$GH_USER_JSON" | jq -r '.email // "\(.id)+\(.login)@users.noreply.github.com"')
git config --global user.name "$GH_USER_NAME"
git config --global user.email "$GH_USER_EMAIL"

cd /home/claude-code/workspace

# Clone if volume is empty, otherwise reset to clean state
if [ ! -d ".git" ]; then
    git clone --branch "$BRANCH" "https://github.com/$REPO" .
else
    git fetch origin
    git checkout "$BRANCH"
    git reset --hard "origin/$BRANCH"
    git clean -fd
fi

# Checkout feature branch (create or reset)
if git ls-remote --heads origin "$FEATURE_BRANCH" | grep -q .; then
    git checkout -B "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH"
else
    git checkout -b "$FEATURE_BRANCH"
    git push -u origin "$FEATURE_BRANCH"
fi

WORKSPACE_DIR=$(pwd)

# Claude Code auth — use OAuth token, not API key
unset ANTHROPIC_API_KEY
export CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN}"

# Skip onboarding and trust dialogs
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "theme": "dark",
  "hasTrustDialogAccepted": true,
  "skipDangerousModePermissionPrompt": true
}
EOF

cat > ~/.claude.json << ENDJSON
{
  "hasCompletedOnboarding": true,
  "projects": {
    "${WORKSPACE_DIR}": {
      "allowedTools": [],
      "hasTrustDialogAccepted": true,
      "hasTrustDialogHooksAccepted": true
    }
  }
}
ENDJSON

# Run Claude Code headlessly
set +e
claude -p "$HEADLESS_TASK" \
    --dangerously-skip-permissions \
    --verbose \
    --output-format stream-json
AGENT_EXIT=$?
set -e

if [ $AGENT_EXIT -eq 0 ]; then
    # Commit + merge back
    git add -A
    git diff --cached --quiet && { echo "NO_CHANGES"; exit 0; }
    git commit -m "feat: headless task" || true
    git fetch origin
    git rebase "origin/$BRANCH" || {
        git rebase --abort
        # If rebase fails, try AI merge-back
        claude -p "$(cat /home/claude-code/.claude/commands/ai-merge-back.md)" \
            --dangerously-skip-permissions || exit 1
    }
    git push --force-with-lease origin HEAD
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
    git merge "$FEATURE_BRANCH"
    git push origin "$BRANCH"
    echo "MERGE_SUCCESS"
else
    echo "AGENT_FAILED"
    exit $AGENT_EXIT
fi
