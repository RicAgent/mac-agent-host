#!/usr/bin/env bash
# Run as the 'agents' user (sudo -iu agents, or ssh agents@mac-studio):
#   bash ~/agents-kit/install/2-agents-setup.sh
# Installs Claude Code for this user, the agent CLI, folders, shell PATH, SSH key folder. Then logs in.
set -euo pipefail
KIT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

echo "== 1. Folders"
mkdir -p "$HOME/agents"/{sessions,prompts,logs,secrets} "$HOME/projects" "$HOME/.local/bin" "$HOME/.ssh"
chmod 700 "$HOME/.ssh" "$HOME/agents/secrets"
touch "$HOME/.ssh/authorized_keys"; chmod 600 "$HOME/.ssh/authorized_keys"

echo "== 2. agent CLI + prompts"
cp "$KIT/bin/agent" "$HOME/.local/bin/agent"; chmod +x "$HOME/.local/bin/agent"
cp -n "$KIT"/prompts/*.md "$HOME/agents/prompts/" 2>/dev/null || true

echo "== 3. PATH for zsh (login + interactive)"
for rc in "$HOME/.zprofile" "$HOME/.zshrc"; do
  grep -q 'agents-kit PATH' "$rc" 2>/dev/null || cat >> "$rc" <<'RC'
# agents-kit PATH
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
RC
done

echo "== 4. Claude Code (native install, per user)"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi
echo "   $(claude --version 2>/dev/null || echo 'claude not on PATH yet — open a new shell')"

echo "== 5. git identity (edit if you want another name)"
git config --global user.name  >/dev/null 2>&1 || git config --global user.name "Agents"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "agents@users.noreply.github.com"

cat <<'NEXT'

DONE (agents part). Now, in this same shell:
  1. claude            -> choose the login method; copy the URL into any browser, paste the code back.
                          The account you log in with PAYS for every session on this Mac.
                          Type /exit when you are in.
  2. gh auth login     -> GitHub, only if the agents will push code.
  3. agent new demo --dir ~/projects/demo --remote "Mac Studio - demo"   (mkdir ~/projects/demo first)
     agent start demo ; agent keys demo Enter    (accepts the 'trust this folder' prompt)
     agent logs demo  ; agent send demo "hello, what machine are you on?"
  4. Open claude.ai/code on the MacBook Air or the phone: the session appears under Remote Control.
NEXT
