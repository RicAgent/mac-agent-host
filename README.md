# mac-agent-host — a Mac Studio as a remote workstation + agent host

Goal: the Mac Studio stays at home, always on, reachable from the MacBook Air (full screen, fluid) and
from claude.ai/code (Remote Control) where persistent Claude Code sessions run under a separate,
non-admin user called `agents`. Same model as the Hostinger server: `agent start/send/logs`, tmux, auto-boot.

## Architecture

```
MacBook Air ──Tailscale──▶ Mac Studio
  Screen Sharing (High Performance)   → friend's own account, GUI work
  ssh agents@mac-studio               → agent CLI (tmux sessions)
claude.ai/code (phone/Air) ──Remote Control──▶ each Claude Code session
```

- Networking: Tailscale on both Macs. No router port forwarding, no public exposure. SSH and VNC only over Tailscale.
- Users: the friend keeps his admin account; `agents` is a Standard user with SSH only, no Screen Sharing, own home, own projects folder.
- Sessions: `~/.local/bin/agent` (this kit) + tmux, started at boot by a LaunchDaemon (no GUI login needed).
- Billing: every session runs on the Claude account logged in from the `agents` user. Pick it deliberately.

## Hands-off mode (preferred)
Install Claude Code in the friend's admin account and let it run the setup: see `START.md` (5 manual minutes) and `SETUP-AGENT.md` (the instructions the session follows, with the human steps it will ask for). The manual runbook below stays as the fallback.

## The 3-hour runbook (manual fallback)

### 0:00 – 0:20 Physical + macOS settings (friend's admin account)
1. Place the Mac Studio, Ethernet in, HDMI dummy plug (or a monitor) in, power on.
2. System Settings > General > Software Update: if a big update is pending, start it **now** or skip it; do not let it block the morning.
3. System Settings > General > Sharing: Local hostname `mac-studio`. Screen Sharing **on** (only the friend's user). Remote Login **on** (friend + agents, added by the script). Remote Management **off**.
4. Energy: Settings > Energy: "Prevent automatic sleeping when the display is off" on, "Wake for network access" on, "Start up automatically after a power failure" on. The script sets the same with `pmset`.
5. FileVault decision (Settings > Privacy & Security):
   - **Off** → after a reboot the Mac boots to the login window with network, Screen Sharing and SSH work. Fine if the flat is safe.
   - **On** → after a reboot it waits for the disk password with no network: unreachable until someone types it. Keep it on only if the friend accepts that remote reboots must use `sudo fdesetup authrestart` and a power failure means a trip home.
6. Firewall on (Settings > Network > Firewall), Tailscale works through it.

### 0:20 – 0:45 Tailscale + remote screen test
1. Install Tailscale on both Macs (tailscale.com/download, standalone build), sign in with the same account, enable MagicDNS in the admin console (default on).
2. On the Air: Finder > Go > Connect to Server > `vnc://mac-studio` → log in as the friend. In the Screen Sharing window: View > "High Performance" (Apple Silicon + macOS 14 on both). Try Adaptive vs full resolution.
3. Switch the Air to the phone hotspot and reconnect: this is the real remote experience. Judge it on his actual apps (Illustrator/Photoshop/Figma…).
4. Fallback if it feels laggy: Jump Desktop (one-off purchase, Fluid protocol, hardware encoded, best-in-class on Mac) — install on both, connect over Tailscale.
5. From the Air: `ssh <friend>@mac-studio` works → SSH is fine.

### 0:45 – 1:30 Agent host, admin part
```
git clone https://github.com/RicAgent/mac-agent-host.git ~/mac-agent-host   # or copy the folder by AirDrop
cd ~/mac-agent-host && bash install/1-admin-setup.sh
```
Creates the `agents` user (asks you for its password), SSH groups, pmset, Homebrew + tmux/jq/gh/node/git, copies the kit to `/Users/agents/agents-kit`, installs `/Library/LaunchDaemons/com.along.agents.plist`.
If Homebrew asks for Xcode Command Line Tools, accept (a few minutes).

### 1:30 – 2:15 Agent host, agents part
```
sudo -iu agents
bash ~/agents-kit/install/2-agents-setup.sh
claude                 # log in with the paying account (URL + code flow works over SSH), then /exit
gh auth login          # optional
mkdir -p ~/projects/demo
agent new demo --dir ~/projects/demo --prompt mac-agent.md --remote "Mac Studio - demo"
agent start demo && sleep 5 && agent keys demo Enter      # accept "trust this folder"
agent logs demo
agent send demo "Hello. Which machine and user are you running as? Write a PROJECT_STATE.md."
```
Then open claude.ai/code on the phone: "Mac Studio - demo" is listed under Remote Control. Chat with it from there.

### 2:15 – 2:40 Shared work folder (optional, only if agents must touch the friend's graphic files)
Keep the friend's home private. Create `/Users/Shared/work`, and give both users access:
```
sudo mkdir -p /Users/Shared/work
sudo chown <friend>:staff /Users/Shared/work
sudo chmod 2775 /Users/Shared/work
sudo chmod +a "agents allow list,add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,file_inherit,directory_inherit" /Users/Shared/work
```
Agents get projects there with `agent new <name> --dir /Users/Shared/work/<name>`.

### 2:40 – 3:00 Reboot test + handover
1. `sudo reboot` from the admin account. Wait 2 minutes.
2. From the Air over hotspot: Screen Sharing works at the login window (FileVault off) → `ssh agents@mac-studio` → `agent status` shows `demo` running (started by launchd) → the session is back in Remote Control.
3. Leave `README.md` on the Desktop with the four commands: `agent status`, `agent start/stop <name>`, `agent send <name> "..."`, `agent logs <name>`.

## Separation model (what the friend keeps, what the agents get)

| Area | agents user | How |
|---|---|---|
| His account, open apps, Keychain, iCloud, browser sessions, Documents/Desktop/Downloads | no access | separate macOS user, home 700 |
| System settings, users, sharing, installs | no | standard (non-admin) user, no sudo |
| CPU, GPU, RAM, network, command-line tools from Homebrew | yes | tools installed by the admin, used by anyone |
| `/Users/Shared/work` | read/write | ACL (see below) |
| External SSDs | **his choice per drive** | `sudo bash install/drive-access.sh /Volumes/<Name> shared\|readonly\|private`; `--list` shows the current state |
| Screen Sharing / GUI | no | allowed only for his user; can be opened later for computer-use tasks |

External drives are the trap: macOS mounts them with "ignore ownership", so every user has full access until the script
enforces ownership and adds a deny ACL for `agents`. exFAT/FAT/NTFS drives have no permissions and stay shared while mounted.

## Day-to-day
- Friend: works on the Studio through Screen Sharing from the Air, anywhere. Nothing to do for the agents.
- Owner / friend from the phone: claude.ai/code → Remote Control → the session; or `ssh agents@mac-studio` over Tailscale.
- New project: `mkdir ~/projects/<name>`, `agent new <name> --dir ~/projects/<name> --prompt mac-agent.md --remote "<label>"`, `agent start <name>`, `agent keys <name> Enter`.
- Giving the owner access from his own machines: in the Tailscale admin console, Machines > mac-studio > Share… (node sharing, free) or add the owner's device to the same tailnet.

## Known limits
- The kit's scripts were written on Linux and not executed on a Mac before the visit: run them line by line if one step fails, every step is a plain shell command.
- A session shows Claude Code's "trust this folder" prompt the first time a folder is used; `agent keys <name> Enter` answers it.
- Claude Code's Remote Control needs the session logged in with a claude.ai account (subscription), not an API key.
- Screen Sharing "High Performance" needs macOS 14+ on both ends and a real display or dummy plug on the host.
