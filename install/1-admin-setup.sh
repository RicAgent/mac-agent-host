#!/usr/bin/env bash
# Run ONCE on the Mac Studio from the owner's ADMIN account (Terminal, will ask for the admin password).
#   bash install/1-admin-setup.sh
# What it does: creates the standard user "agents", enables Remote Login (SSH) and Screen Sharing,
# sets the Mac to never sleep, installs Homebrew tools, installs the launchd unit that boots the sessions.
set -euo pipefail
AGENT_USER=${AGENT_USER:-agents}
KIT=$(cd "$(dirname "$0")/.." && pwd)

echo "== 1. Create user '$AGENT_USER' (standard, not admin)"
if id "$AGENT_USER" >/dev/null 2>&1; then
  echo "   user exists, skipping"
else
  read -r -s -p "   password for the new '$AGENT_USER' user: " AGENT_PW; echo
  sudo sysadminctl -addUser "$AGENT_USER" -fullName "Agents" -password "$AGENT_PW" -shell /bin/zsh
  unset AGENT_PW
fi
sudo mkdir -p "/Users/$AGENT_USER/projects" && sudo chown "$AGENT_USER" "/Users/$AGENT_USER/projects"

echo "== 2. Remote Login (SSH) for the admin and '$AGENT_USER'"
sudo systemsetup -setremotelogin on >/dev/null 2>&1 || true
sudo dseditgroup -o edit -a "$AGENT_USER" -t user com.apple.access_ssh 2>/dev/null || true
sudo dseditgroup -o edit -a "$USER" -t user com.apple.access_ssh 2>/dev/null || true

echo "== 3. Screen Sharing (VNC) for the admin only"
sudo launchctl enable system/com.apple.screensharing 2>/dev/null || true
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
echo "   if this did not stick, turn it on by hand: System Settings > General > Sharing > Screen Sharing (allow: $USER)"

echo "== 4. Never sleep, wake on LAN, restart after power failure"
sudo pmset -a sleep 0 disksleep 0 womp 1 autorestart 1 powernap 0 displaysleep 15

echo "== 5. Homebrew + tools (tmux jq gh node git)"
if ! command -v brew >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/brew ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install tmux jq gh node git >/dev/null
echo "   tmux $(tmux -V | cut -d' ' -f2), node $(node -v)"

echo "== 6. Copy the kit to /Users/$AGENT_USER/agents-kit"
sudo rm -rf "/Users/$AGENT_USER/agents-kit"
sudo cp -R "$KIT" "/Users/$AGENT_USER/agents-kit"
sudo chown -R "$AGENT_USER" "/Users/$AGENT_USER/agents-kit"

echo "== 7. launchd unit: start all AUTOSTART sessions at boot (no GUI login needed)"
sudo sed "s/__USER__/$AGENT_USER/g" "$KIT/install/com.along.agents.plist" > /tmp/com.along.agents.plist
sudo cp /tmp/com.along.agents.plist /Library/LaunchDaemons/com.along.agents.plist
sudo chown root:wheel /Library/LaunchDaemons/com.along.agents.plist
sudo chmod 644 /Library/LaunchDaemons/com.along.agents.plist
sudo launchctl bootout system/com.along.agents 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.along.agents.plist
echo "   loaded: $(sudo launchctl print system/com.along.agents 2>/dev/null | grep -m1 state || echo 'see launchctl')"

echo
echo "DONE (admin part). Next, as the agents user:"
echo "   sudo -iu $AGENT_USER"
echo "   bash ~/agents-kit/install/2-agents-setup.sh"
