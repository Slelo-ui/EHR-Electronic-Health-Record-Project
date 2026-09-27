# EHR platform

An electronic health record with a web app (clinical and patient portal) and a Mac/Windows desktop app. It is designed to be secure first and as fast as the hardware allows. One on-prem PostgreSQL primary owns every write; everything else is a copy, a cache, or a proxy.

## Status

Early foundation. No EHR features exist yet.

**Working today**

- The desktop app (Tauri) opens a blank window. Verified on an Apple Silicon Mac; Windows is not yet verified.
- The web app (ASP.NET Core Razor Pages) serves a blank page, locally and inside the server stack.
- The local server stack runs the whole server architecture in Docker Compose: the PostgreSQL 18 primary, its streaming replica, Barman backups with point-in-time restore, and a simulated WAN. Verified on Linux, and on an Apple Silicon Mac for replication, isolation, backups and restore; Windows is not yet verified.
- Dependency manifests and toolchain versions are in place. Python packages use version ranges until a lockfile is added.

**Not built yet:** the database schema and policies, sign-in and authorization, the clinical workflows, the patient portal, desktop sync, dictation, and the tests themselves (the test projects exist but are empty).

## Layout

Folders describe their intended contents; most are still empty.

```
src/
  Ehr.Web/          ASP.NET Core Razor Pages host: Areas/Clinical, Areas/Portal, Api/Sync, Api/Dictation
  Ehr.Domain/       services, authorization policies, PHI reader, FHIR-shaped models
  Ehr.Data/         EF Core + Dapper on Npgsql: read and write contexts, RLS interceptor
  Ehr.Design/       Razor class library: design tokens, CSS, sprite sheet, shared partials, htmx, Alpine.js
  Ehr.Desktop/      Tauri 2 app: src-tauri (Rust shell, SQLCipher, sync) + frontend
  Ehr.Dictation/    sidecar (Python, MedASR), llama-server config, note schema
tests/
  Ehr.Security.Tests/      RLS, role, and audit gates against real PostgreSQL 18
  Ehr.Architecture.Tests/  layering, and PHI reads only through the PHI reader
db/
  migrations/       EF-generated
  policies/         RLS, triggers, roles (hand-written, human-reviewed)
eval/               dictation gold set and scoring
bench/              load tests and budget assertions
infra/              compose (local server stack), barman (backup image), tailscale (access rules)
.vscode/            shared settings, recommended extensions, and run tasks
AGENTS.md           conventions every coding agent follows
```

## Supported machines

Development and the desktop app: Apple Silicon Macs, and Windows PCs with Intel or AMD CPUs and NVIDIA or AMD GPUs. Servers and CI run Linux.

## Setup

Everyone:

| Tool | Version | Pinned in, or how to install |
|---|---|---|
| .NET SDK | 10.0 (LTS) | `global.json` |
| Rust, via rustup | 1.98.1 | `src/Ehr.Desktop/src-tauri/rust-toolchain.toml`; installs itself on the first build |
| Tauri CLI | 2.x | `cargo binstall tauri-cli --version "^2"` (prebuilt, seconds) or `cargo install tauri-cli --version "^2" --locked` (compiles, minutes) |
| uv, for Python 3.12+ | | `pyproject.toml` in `src/Ehr.Dictation/sidecar` and `eval` |
| Docker Desktop | Compose v2 | For the local server stack |
| mkcert | | Local HTTPS certificates for the server stack |
| VS Code | | Accept the recommended extensions: C# Dev Kit, rust-analyzer, Tauri |

**Apple Silicon Mac**

- Xcode Command Line Tools (`xcode-select --install`) for the compiler and `make`. macOS already ships the Perl that the vendored OpenSSL build needs.
- Docker Desktop: open it once, and under Settings → Advanced choose **System** for the CLI tools, so every shell (including VS Code's) finds `docker`. Its default memory is enough for the server stack; only the `ai` profile needs more (see `infra/compose/README.md`).

**Windows PC**

- Visual Studio Build Tools with the "Desktop development with C++" workload. Keep rustup's default MSVC toolchain.
- Strawberry Perl, ahead of Git's Perl on `PATH`. The vendored OpenSSL build rejects Git Bash's Perl, so build from PowerShell, not Git Bash.
- Docker Desktop with the WSL2 backend (virtualization enabled in the firmware). Its default memory is enough for the server stack; for the `ai` profile, raise `memory` in `%UserProfile%\.wslconfig`.
- Clone to a short path outside OneDrive, such as `C:\src\ehr`. The OpenSSL build nests deep enough to hit Windows' 260-character path limit, and OneDrive locks files mid-build.
- NASM is not needed: `src/Ehr.Desktop/src-tauri/.cargo/config.toml` lets the TLS library use its prebuilt objects.

**If VS Code can't find a tool** (`command not found` for `cargo`, `dotnet` or `docker`): it was opened before the tool was installed. Quit VS Code completely (Cmd+Q on macOS) and reopen it.

## Running the blank apps

**Desktop app:**

```
cd src/Ehr.Desktop/src-tauri
cargo tauri dev
```

The first build takes several minutes because it downloads the pinned Rust and compiles SQLCipher and OpenSSL; later builds are quick. A blank window titled "EHR" opens.

**Web app:**

```
dotnet run --project src/Ehr.Web
```

Then open http://localhost:5080. It avoids port 5000, which macOS's AirPlay Receiver uses. The first build needs internet access to download htmx and Alpine.js.

**In VS Code:** open the repository folder, then use Terminal → Run Task:

| Task | What it does |
|---|---|
| Run desktop app | `cargo tauri dev` |
| Run web app | `dotnet run --project src/Ehr.Web` |
| Server stack: start | Builds and starts the local server stack |
| Server stack: stop | Stops it and keeps its data |
| Server stack: reset | Stops it and deletes all its data |

**Tests:** `dotnet test` runs the test projects, but they have no tests yet, so it reports "Zero tests ran" (exit code 8) until the security and architecture gates are written.

## Local server stack

`infra/compose` runs the whole server architecture on one machine with Docker Compose: the on-prem primary and app, the cloud replica and app, the isolated Barman backup host, and a simulated WAN with latency between them. It also covers the failure drills and a point-in-time restore. Setup (certificates and hosts-file entries) and every command are in [infra/compose/README.md](infra/compose/README.md).

## Where dependencies are declared

| Area | File |
|---|---|
| .NET package versions | `Directory.Packages.props` |
| htmx, Alpine.js (CSP build) | `src/Ehr.Design/libman.json`, restored into `wwwroot/lib` at build and served from our own origin |
| Desktop | `src/Ehr.Desktop/src-tauri/Cargo.toml` |
| MedASR sidecar | `src/Ehr.Dictation/sidecar/pyproject.toml` |
| Dictation eval | `eval/pyproject.toml` |
| Container images for the local stack | `infra/compose/compose.yaml`, `infra/barman/Dockerfile`, `src/Ehr.Web/Dockerfile` |

## Dictation server hardware

Llama 3.1 runs in llama.cpp's `llama-server`, pinned to build **b11176** on every machine. In the local stack it's the opt-in `ai` profile. MedASR will run in Docker on CPU, since the model is small; its sidecar isn't written yet.

| Server machine | How `llama-server` runs |
|---|---|
| Windows, NVIDIA GPU | In Docker: the `ai` profile plus `infra/compose/compose.nvidia.yaml`, which switches to `server-cuda-b11176`. Docker Desktop passes NVIDIA GPUs through WSL2; keep the NVIDIA driver current. Plan on 8 GB of GPU memory; 6 GB fits one request at a time. |
| Windows, AMD GPU | Natively: the b11176 Windows Vulkan build from the llama.cpp GitHub release. Docker Desktop can't use AMD GPUs. |
| Apple Silicon Mac | Natively: the b11176 macOS arm64 build, which uses Metal. Or Podman with krunkit running `server-vulkan-b11176`, which keeps it in a container at roughly 75–80% of native speed. Docker Desktop can't use the Mac's GPU. |
| No usable GPU | In Docker: the `ai` profile as is (`server-b11176`), on CPU. |

- A native `llama-server` sits outside the Compose network, so nothing enforces "no internet egress" for it. Start it with a local model file, never with a flag that downloads one.
- Record the dictation eval baseline on the server machine itself. CUDA, Vulkan, Metal and CPU builds can produce slightly different output, even at temperature 0.

## Runtime dependencies outside the package managers

For local development, PostgreSQL 18, Barman and the WAN simulation (Toxiproxy 2.12) come as containers in the local server stack, so there's nothing to install. The real deployment also needs:

- PostgreSQL 18 (primary and hot standby)
- Barman, in streaming mode
- Tailscale
- llama.cpp `llama-server`, build b11176 (see above)
- ffmpeg
- Model weights, downloaded during setup and never committed:
  - MedASR 1.0. The weights are gated: accept the Health AI Developer Foundations terms on Hugging Face first.
  - Llama 3.1 8B Instruct, 4-bit GGUF (about 5 GB). The Llama 3.1 Community License requires displaying "Built with Llama" and shipping its notice file.
