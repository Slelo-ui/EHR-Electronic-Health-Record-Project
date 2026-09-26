# AGENTS.md

Conventions every coding agent (and every person) follows in this repo. Most come from the project overview; the cross-platform rules come from the machines the team uses.

## Where authorization is applied

- Twice, always: ASP.NET Core policies in the app, then row-level security (RLS) in PostgreSQL. A missed check in code must still return no unauthorized rows.
- Policies attach to whole areas by convention (`Areas/Clinical`, `Areas/Portal`, `Api/Sync`), not handler by handler.
- Portal handlers never accept a patient ID. The subject always comes from the session.
- Every PHI read goes through the PHI reader service in `Ehr.Domain`, which records an audit event.
- RLS is enabled and forced on every PHI table. The app connects as `ehr_app` or `ehr_read`, which own nothing and lack `BYPASSRLS`.
- Network position is never identity. Being on the LAN never skips authentication.

## Where raw SQL is allowed

- Dapper, for hot reads, inside `Ehr.Data` only. It borrows EF Core's connection and transaction so the RLS context applies.
- The RLS context is set with `set_config(..., true)` as the first statement of every transaction. Plain `SET` is banned: on a pooled connection it can leak into the next request.
- `db/policies` (RLS, triggers, roles) is hand-written SQL.
- Sync watermarks use transaction IDs, never timestamps.

## How migrations are made

- Schema: EF Core migrations, generated into `db/migrations`.
- RLS, triggers, and roles: hand-written in `db/policies`.
- Migrations run as `ehr_owner`, in CI and deploy only. The running app never uses that role.

## Human review

Changes to the following get line-by-line review by someone other than the person who prompted the agent:

- `db/policies`
- authorization attributes and policies
- the sync conflict resolver
- the dictation prompt and note schema

## What "done" means

Every CI gate passes:

- Every PHI table has RLS enabled and forced, plus a write-audit trigger.
- No runtime role owns a table or has `BYPASSRLS`.
- Querying a PHI table without `app.user_id` set returns zero rows.
- An architecture test proves PHI reads only go through the PHI reader.
- p99 server render under 20 ms on 50,000 seeded patients; page JavaScript under 50 KB; first contentful paint under 500 ms.
- macOS and Windows desktop builds succeed.
- Dictation eval scores do not drop below the last accepted baseline.

## Cross-platform

The team develops on Apple Silicon Macs and Intel/AMD Windows PCs; servers and CI run Linux.

- Line endings are LF (`.gitattributes`). Only `.cmd` and `.bat` files use CRLF.
- Match the case of file and folder names exactly. Macs and Windows ignore case; the Linux servers don't.
- No bash-only scripts. Use `dotnet run script.cs` (.NET 10) or PowerShell 7, which run on both.
- Container images are built in CI for `linux/amd64` and `linux/arm64`, never pushed from a laptop. Macs build arm64 images that an x86-64 server can't run.
- PostgreSQL data lives in Docker named volumes, not host folders.
- The desktop app makes network calls from Rust, not from the web view. The web view's origin differs by OS: `tauri://localhost` on macOS, `http://tauri.localhost` on Windows.
- Never hard-code an audio recording format. WebKit (Safari, the macOS app) and Chromium (Chrome, Edge, the Windows app) record different containers; ffmpeg normalizes both on the server.

## Always

- Secrets come from environment configuration, never the repo.
- All data is synthetic.
