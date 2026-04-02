# Gboy Companion Native

The native macOS companion is the AppKit desktop-pet build of Gboy. It packages as a standalone `.app`, uses sprite sheets from `../godot-game/assets/sprites/player/`, and includes the local AI chat, memory, and animation routing layer.

## Features

- Transparent always-on-top desktop companion window
- Drag, fling, wall and ceiling attachment, cursor reactions, smoke movement, and desktop notes
- Large native animation loop with patrol, hacker, graffiti, sleep, glitch, and power behaviors
- Native chat window with persistent memory
- Live knowledge lookups from Wikipedia, Wikidata, and Open Library
- Pluggable AI providers:
  - local `ollama`
  - OpenAI-compatible HTTP APIs

## Dependencies

Required:

- macOS 13+
- Xcode Command Line Tools with `swiftc`
- Python 3
- Pillow for sheet generation:

```bash
python3 -m pip install pillow
```

Optional AI dependencies:

- `ollama` for local chat
- Any OpenAI-compatible API if you want hosted or remote inference

## Build

```bash
chmod +x build_app.sh
./build_app.sh
open "build/Gboy Companion Native.app"
```

Smoke test:

```bash
./build_app.sh
"build/Gboy Companion Native.app/Contents/MacOS/gboy-companion-native" --smoke-test
```

## AI Files

Bundled AI defaults live in:

- `Assets/AI/character.json`
- `Assets/AI/provider.json`
- `Assets/AI/memory.json`
- `Assets/AI/provider.ollama.example.json`
- `Assets/AI/provider.openai.example.json`
- `Assets/AI/provider.claude.example.json`
- `Assets/AI/provider.openai-compatible.example.json`

On first launch, the app copies editable versions into:

- `~/Library/Application Support/Gboy Companion Native/AI/character.json`
- `~/Library/Application Support/Gboy Companion Native/AI/provider.json`
- `~/Library/Application Support/Gboy Companion Native/AI/memory.json`

You can open those files from the app menu under `AI`.

## Local AI Setup

Default local provider:

- `kind: "ollama"`
- default model: `qwen2.5:3b-instruct`

Install and pull a model:

```bash
ollama pull qwen2.5:3b-instruct
```

The default provider uses `ollama` from your `PATH`.

## API Setup

The app menu has one-click provider presets under:

- `AI`
- `Provider Presets`

Available presets:

- `Use Ollama`
- `Use OpenAI`
- `Use Claude`
- `Use OpenAI-Compatible`

Those presets replace your editable `provider.json` and then open it so you can finish setup.

### OpenAI

Use the `Use OpenAI` preset, then export:

```bash
export OPENAI_API_KEY="your-key-here"
```

Edit `apiModel` if you want a different OpenAI model.

### Claude

Use the `Use Claude` preset, then export:

```bash
export ANTHROPIC_API_KEY="your-key-here"
```

Edit `apiModel` if you want a different Claude model.

### Generic OpenAI-Compatible APIs

For a hosted or local API server, use the `Use OpenAI-Compatible` preset and fill in:

- `apiBaseURL`
- `apiPath`
- `apiModel`
- `apiKeyEnvVar`

Then export the API key in your shell, for example:

```bash
export GBOY_API_KEY="your-key-here"
```

This connector expects an OpenAI-compatible `chat/completions` endpoint and reads the key from an environment variable instead of storing secrets in the repo.

## Publishable Repo Notes

This repo is set up so it can be published without machine-specific AI paths or local secrets:

- no personal home-directory paths are required for the shipped AI config
- local secrets should stay in environment variables
- build output is ignored
- `.DS_Store`, `.app`, and local override files are ignored
- the repo layout is now stable for GitHub publishing with current build assets under `apps/`

## Notes

- The native companion is intentionally macOS-specific.
- Live knowledge lookups are read-only and use free public endpoints.
- More invasive desktop automation should stay behind a separate permission-gated pass.
