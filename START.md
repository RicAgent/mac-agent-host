# START.md — the only things the operator does by hand (5 minutes)

On the Mac Studio, logged in as the friend (his admin account), open Terminal:

```
# 1. temporary passwordless sudo for the setup session (removed in the last phase)
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/claude-setup

# 2. Claude Code for this account
curl -fsSL https://claude.ai/install.sh | bash
exec zsh

# 3. the kit (git may ask to install Xcode Command Line Tools: accept, wait, rerun)
git clone https://github.com/RicAgent/mac-agent-host.git ~/mac-agent-host || echo "no access: unpack mac-agent-host.tgz into ~/mac-agent-host instead"
cd ~/mac-agent-host

# 4. start the setup session (log in with the FRIEND's Claude account when asked: it pays everything on this Mac)
claude --permission-mode auto
```

First message to type:

> Read README.md, CHECKLIST.md and SETUP-AGENT.md in this folder, then perform the whole setup in SETUP-AGENT.md phase by phase, within 3 hours. I am sitting next to the Mac with its owner; speak Italian with us. Whenever you need a human, write "HUMAN STEP n:" with the exact action and wait for "done". Verify every step with a command. Start with Phase 0 and report what you found before changing anything.

After the reboot in Phase 6, open Terminal again, `cd ~/mac-agent-host && claude --continue` (or `claude` and "Read SETUP-AGENT.md and SETUP-LOG.md, we are at Phase 7") to finish the cleanup.

If `--permission-mode auto` is not accepted by this Claude Code version, start plain `claude` and press Shift+Tab until the prompt shows auto or accept-edits mode, then approve the first commands by hand.
