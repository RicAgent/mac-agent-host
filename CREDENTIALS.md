# CREDENTIALS.md — how the agents get access to apps and services (optional Phase 8, after the core setup)

Principle: the friend's password manager is the source of truth; the agents never see it. They get only
scoped tokens, in files owned by the `agents` user, one per service, loaded into a session with `--env`.

## Layout on the Mac (as the agents user)
```
~/agents/secrets/            chmod 700
  umbrella.env               chmod 600 — shared tokens: GITHUB_TOKEN, VERCEL_TOKEN, SUPABASE_ACCESS_TOKEN, RESEND_API_KEY, ...
  <project>.env              chmod 600 — project-specific keys, when needed
```
A profile uses them with `agent new <name> --dir ... --env umbrella.env`; the session sees them as environment variables.
Project secrets that the code itself needs live in the project's `.env.local` (git-ignored), never in chat or commits.

## Rules for the tokens
- One token per service, created for "agents", scoped as small as possible: GitHub fine-grained PAT limited to the repos the
  agents work on; Vercel token on a dedicated team; Supabase access token; API keys with their own name in the provider's dashboard.
- Never the friend's own session cookies, Apple ID, Google account or main passwords. If a service has no tokens, create a second
  account for the agents and share with it only what they need.
- Every token is also saved in his password manager (1Password or Bitwarden, free) under a tag `agents`, with the date.
  Rotation = regenerate in the dashboard, replace the line in the file, `agent restart <name>`.
- Check what is set without printing values: `grep -o '^[A-Z_]*=' ~/agents/secrets/umbrella.env`.

## CLI logins (once, as the agents user over SSH)
- `gh auth login` → device code, works in a terminal without a browser on the Mac (open the URL on any device).
- Vercel: `export VERCEL_TOKEN=...` from the env file; `vercel whoami --token "$VERCEL_TOKEN"` to verify.
- Supabase: `SUPABASE_ACCESS_TOKEN` in the env file; `supabase projects list` to verify.
- npm, pipx and similar: per-user installs under `~/.local`, no admin needed.

## MCP servers in Claude Code
- Token-based or local MCPs: `claude mcp add --scope user <name> ...` as the agents user; config lands in `~/.claude.json`.
- OAuth-based remote MCPs (Vercel, Figma, Notion, Google...): the login needs a browser ON THIS MAC in the agents user's session.
  Do it once: temporarily allow the agents user in System Settings > Sharing > Screen Sharing, connect from the Air with
  `vnc://mac-studio` as `agents` (it opens a separate virtual desktop, his session is untouched), run `claude`, `/mcp`,
  complete the logins in Safari, quit, then remove `agents` from Screen Sharing again. Tokens stay in the agents user's Keychain.
- Prefer token-based access where a service offers both; it survives reboots and needs no screen.

## Which services, decided with him
Typical for a designer's agents: GitHub, Vercel, a Figma token or Figma MCP, Google Drive or Dropbox for assets, Notion,
an email API (Resend) for transactional mail, an image API if he wants generation. Write the final list and the token scopes
in SETUP-LOG.md.
