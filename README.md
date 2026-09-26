# EHR platform

An electronic health record with a web app (clinical and patient portal) and a Mac/Windows desktop app. It is designed to be secure first and as fast as the hardware allows. One on-prem PostgreSQL primary owns every write; everything else is a copy, a cache, or a proxy.

**Status:** scaffold only. Dependency manifests and folder structure, no application code yet.

## Layout

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
infra/              Compose topology, Barman, Tailscale ACLs
AGENTS.md           conventions every coding agent follows
```

## Supported machines

Development and the desktop app: Apple Silicon Macs, and Windows PCs with Intel or AMD CPUs and NVIDIA or AMD GPUs. Servers and CI run Linux.

## Setup

Everyone:

| Tool | Version | Pinned in |
|---|---|---|
| .NET SDK | 10.0 (LTS) | `global.json` |
| Rust, via rustup | 1.98.1 | `src/Ehr.Desktop/src-tauri/rust-toolchain.toml` |
| Tauri CLI | 2.x | `cargo install tauri-cli --version "^2" --locked` |
| uv, for Python 3.12+ | | `pyproject.toml` in `src/Ehr.Dictation/sidecar` and `eval` |
| Docker Desktop | Compose v2 | |

**Apple Silicon Mac**

- Xcode Command Line Tools (`xcode-select --install`) for the compiler and `make`. macOS already ships the Perl that the vendored OpenSSL build needs.
- Docker Desktop: raise the memory limit in Settings → Resources before running the full stack.

**Windows PC**

- Visual Studio Build Tools with the "Desktop development with C++" workload. Keep rustup's default MSVC toolchain.
- Strawberry Perl, ahead of Git's Perl on `PATH`. The vendored OpenSSL build rejects Git Bash's Perl.
- Docker Desktop with the WSL2 backend (virtualization enabled in the firmware). WSL2 gets half the RAM by default; raise `memory` in `%UserProfile%\.wslconfig` before running the full stack.
- Clone to a short path outside OneDrive, such as `C:\src\ehr`. The OpenSSL build nests deep enough to hit Windows' 260-character path limit, and OneDrive locks files mid-build.
- NASM is not needed: `src/Ehr.Desktop/src-tauri/.cargo/config.toml` lets the TLS library use its prebuilt objects.

## Where dependencies are declared

| Area | File |
|---|---|
| .NET package versions | `Directory.Packages.props` |
| htmx, Alpine.js (CSP build) | `src/Ehr.Design/libman.json`, restored into `wwwroot/lib` at build and served from our own origin |
| Desktop | `src/Ehr.Desktop/src-tauri/Cargo.toml` |
| MedASR sidecar | `src/Ehr.Dictation/sidecar/pyproject.toml` |
| Dictation eval | `eval/pyproject.toml` |

## Dictation server hardware

Whichever machine is the on-prem server, MedASR runs in Docker on CPU; the model is small. Llama 3.1 runs in llama.cpp's `llama-server`, pinned to build **b11176** on every machine:

| Server machine | How `llama-server` runs |
|---|---|
| Windows, NVIDIA GPU | In Docker: `ghcr.io/ggml-org/llama.cpp:server-cuda-b11176`. Docker Desktop passes NVIDIA GPUs through WSL2; keep the NVIDIA driver current. Plan on 8 GB of GPU memory; 6 GB fits one request at a time. |
| Windows, AMD GPU | Natively: the b11176 Windows Vulkan build from the llama.cpp GitHub release. Docker Desktop can't use AMD GPUs. |
| Apple Silicon Mac | Natively: the b11176 macOS arm64 build, which uses Metal. Or Podman with krunkit running `server-vulkan-b11176`, which keeps it in a container at roughly 75–80% of native speed. Docker Desktop can't use the Mac's GPU. |
| No usable GPU | In Docker: `ghcr.io/ggml-org/llama.cpp:server-b11176`, on CPU. |

- A native `llama-server` sits outside the Compose network, so nothing enforces "no internet egress" for it. Start it with a local model file, never with a flag that downloads one.
- Record the dictation eval baseline on the server machine itself. CUDA, Vulkan, Metal and CPU builds can produce slightly different output, even at temperature 0.

## Runtime dependencies outside the package managers

- PostgreSQL 18 (primary and hot standby)
- Barman, in streaming mode
- Tailscale
- llama.cpp `llama-server`, build b11176 (see above)
- ffmpeg
- Model weights, downloaded during setup and never committed:
  - MedASR 1.0. The weights are gated: accept the Health AI Developer Foundations terms on Hugging Face first.
  - Llama 3.1 8B Instruct, 4-bit GGUF (about 5 GB). The Llama 3.1 Community License requires displaying "Built with Llama" and shipping its notice file.
