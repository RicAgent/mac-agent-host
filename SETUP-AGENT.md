# SETUP-AGENT.md — instructions for the Claude Code session that performs the setup

You are running on a Mac Studio, inside the admin account of its owner (the "friend"). Next to you sits a
second person (the "operator") who installed you and will do the few manual steps. Your job: turn this Mac
into an always-on remote workstation plus a Claude Code agent host, following this file to the end, and
finish with a written report. Converse in English; the operator may write Italian, answer in English unless asked.

## Ground rules
- Do every step yourself with shell commands. Ask the operator only for a HUMAN STEP (listed below) and only
  when you reach it. Phrase it as: `HUMAN STEP <n>: <exact thing to do>` then wait for "done".
- Verify every step with a command before moving on. If something fails, read the error, try one alternative,
  then ask the operator. Never skip a verification.
- Never print passwords, tokens or the content of key files. Never touch the friend's documents.
- Keep `SETUP-LOG.md` in this folder updated after each phase (what was done, what was verified, anything open).
- The repo you are in is `mac-agent-host`. Read `README.md` and `CHECKLIST.md` first for context; `install/` has
  the scripts, `bin/agent` the CLI, `prompts/mac-agent.md` the default session prompt.

## Phase 0 — discover
1. `sw_vers`, `uname -m`, `sysctl -n machdep.cpu.brand_string`, `whoami`, `hostname`, `df -h /`, `id`.
   Require Apple Silicon and macOS 14+. If older, say so and continue (High Performance screen sharing will not exist).
2. `sudo -n true` must succeed (the operator created a temporary passwordless sudo rule, see START.md).
   If not: HUMAN STEP 0: in a second Terminal run `echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/claude-setup`.
3. `fdesetup status` (FileVault), `pmset -g`, `networksetup -listallhardwareports` (is Ethernet connected?),
   `system_profiler SPDisplaysDataType | grep -i resolution` (is a display or dummy plug attached?).
   Report the four facts to the operator in one line each before changing anything.

## Phase 1 — machine settings
1. Hostname: `sudo scutil --set ComputerName mac-studio; sudo scutil --set LocalHostName mac-studio; sudo scutil --set HostName mac-studio`.
2. Energy: `sudo pmset -a sleep 0 disksleep 0 womp 1 autorestart 1 powernap 0 displaysleep 15`. Verify with `pmset -g`.
3. Remote Login: `sudo systemsetup -setremotelogin on`; verify `sudo systemsetup -getremotelogin` says On.
   If the command is refused, HUMAN STEP 1: System Settings > General > Sharing > Remote Login: on.
4. Screen Sharing: `sudo launchctl enable system/com.apple.screensharing && sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist` (ignore "already loaded").
   Verify: `sudo launchctl print system/com.apple.screensharing | grep -m1 state` or `nc -z localhost 5900`.
   If not listening, HUMAN STEP 2: System Settings > General > Sharing > Screen Sharing: on, allow only the friend's user.
5. Firewall: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on`.
6. FileVault: if `fdesetup status` says On, explain the trade-off to the operator in three lines (after a reboot the
   Mac is unreachable until someone types the disk password; remote reboots must use `sudo fdesetup authrestart`).
   Ask: keep or disable? If disable: HUMAN STEP 3: System Settings > Privacy & Security > FileVault > Turn Off
   (needs the friend's password; decryption continues in background, no need to wait).
7. Software update: `softwareupdate -l` — only report what is pending, do not install today.

## Phase 2 — Tailscale
1. `brew --version` or install Homebrew: `NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`,
   then `eval "$(/opt/homebrew/bin/brew shellenv)"` and add that line to `~/.zprofile` if missing.
2. `brew install --cask tailscale-app` (if that cask name fails, try `tailscale`); `open -a Tailscale`.
3. `/Applications/Tailscale.app/Contents/MacOS/Tailscale up` prints a login URL, or the app shows a login window.
   HUMAN STEP 4: the friend logs in to Tailscale in the browser with his Google or Apple account (new account is fine, free).
   Verify: `/Applications/Tailscale.app/Contents/MacOS/Tailscale status` shows this machine and an IP 100.x.y.z. Record the name and IP.
4. If the Tailscale menu shows "MagicDNS off", tell the operator to enable it later in the admin console (login.tailscale.com > DNS).

## Phase 3 — tools and the agents user (install/1-admin-setup.sh does this; run it, do not retype it)
1. `bash install/1-admin-setup.sh` from this folder. It prompts once for the new `agents` user password:
   HUMAN STEP 5: the operator types a password for the `agents` user (and writes it down for the friend).
   Everything else in the script is non-interactive with sudo.
2. Verify: `id agents`, `dscl . -read /Groups/com.apple.access_ssh GroupMembership`, `ls -la /Users/agents/agents-kit`,
   `sudo launchctl print system/com.along.agents | head -5`, `brew list | tr '\n' ' '` (tmux jq gh node git present).

## Phase 4 — Claude Code for the agents user
1. `sudo -iu agents bash /Users/agents/agents-kit/install/2-agents-setup.sh`. Verify: `sudo -iu agents bash -lc 'claude --version; agent help | head -3'`.
2. Login must be interactive, so drive it through tmux as the agents user:
   `sudo -iu agents bash -lc 'tmux new-session -d -s login "claude"'`, wait 5 s, then
   `sudo -iu agents bash -lc 'tmux capture-pane -p -t login'` and look for the login menu; send `Enter` for the subscription option
   (`tmux send-keys -t login Enter`), capture again, find the URL.
   HUMAN STEP 6: open the printed URL in Safari, log in with the Claude account that will PAY for the agents (decided by the operator),
   copy the code shown, paste it to me here in chat. Then you send it with `tmux send-keys -t login -l "<code>"` and `Enter`.
   Verify login: capture the pane until the prompt appears, then send `/exit` + Enter and `tmux kill-session -t login`.
   If this dance fails twice: HUMAN STEP 6b: operator opens a second Terminal, runs `sudo -iu agents` then `claude`, logs in by hand, `/exit`.
3. Optional GitHub for the agents user: ask the operator whether agents will push code. If yes: same tmux trick with
   `gh auth login --web`, the human opens the URL and enters the one-time code.

## Phase 5 — first session
As the agents user (`sudo -iu agents bash -lc '...'`):
1. `mkdir -p ~/projects/demo`
2. `agent new demo --dir ~/projects/demo --prompt mac-agent.md --remote "Mac Studio - demo"`
3. `agent start demo`; wait 8 s; `agent logs demo`. If it shows "trust this folder", `agent keys demo Enter`.
4. `agent send demo "Hello. Which machine and user are you running as? Create PROJECT_STATE.md with that info."`; after 30 s `agent logs demo`.
5. Tell the operator: HUMAN STEP 7: open claude.ai/code on your phone, confirm "Mac Studio - demo" is listed under Remote Control and send it a message there.

## Phase 6 — reboot test
1. Save `SETUP-LOG.md`. Tell the operator exactly what will happen: the Mac reboots, you (this session) will die,
   and they must check from the MacBook Air on the phone hotspot: (a) Screen Sharing to mac-studio reaches the login window,
   (b) `ssh agents@mac-studio` works, (c) `agent status` shows demo running, (d) the session is back in Remote Control.
2. Ask for an explicit "go", then `sudo reboot`.

## Phase 7 — cleanup (after the reboot, when the operator restarts you with `claude --resume` or a new session reading this file)
1. `sudo rm -f /etc/sudoers.d/claude-setup`; verify `sudo -n true` now FAILS.
2. If the operator logged in to Claude Code in the friend's admin account with the operator's own account, run `claude` → `/logout` there,
   or tell the operator to do it. Ask which it is.
3. Write `~/Desktop/AGENTS-HOWTO.txt` for the friend: how to reach the Mac from the Air (vnc://mac-studio, High Performance),
   `ssh agents@mac-studio`, the four agent commands, how to create a new project session, where the logs are, who to call.
4. Print the MacBook Air checklist for the operator (Air is not touched by you): install Tailscale, same account; Finder > Go >
   Connect to Server `vnc://mac-studio`, View > High Performance; test on phone hotspot; Jump Desktop if laggy; `ssh agents@mac-studio`.
5. Final report in chat: what is set up, Tailscale name/IP, the agents user, which Claude account pays, FileVault state,
   anything left open. Copy the same into SETUP-LOG.md.
