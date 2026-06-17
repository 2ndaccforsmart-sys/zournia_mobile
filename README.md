# Zournia Mobile — AI Phone Controller & Automation Suite

A full-stack AI automation system that controls your Android phone like a human. Includes a PC-style cursor, dynamic app discovery, media search, and phone control — all powered by AI.

## Features

### Phone Control (AI-Driven)
- **TAP** — AI taps at screen coordinates with animated cursor
- **SWIPE** — AI swipes with human-like movement
- **TYPE** — AI types text via keyboard
- **NAV** — Back, home, recents, enter, delete, tab, escape, power, volume
- **SCREENSHOT** — Capture screen state
- **DUMPUI** — Scan screen, list all UI elements with coordinates

### PC-Style Cursor Overlay
- Cubic Bezier curve movement with micro-jitter (human-like hand tremor)
- Cyan trail showing cursor path
- Click ripple animation
- Variable speed based on distance

### Dynamic App Discovery
- Scans installed apps every 12 hours in background (headless, no user input)
- Resolves launcher activities automatically
- Builds its own knowledge of how to operate apps on your phone
- 70+ known apps pre-mapped for instant recognition

### Media Search & Playback
- **SEARCH: platform query** — YouTube, Spotify, Netflix, TikTok, Google, Amazon, Twitch, SoundCloud
- Deep links into apps, falls back to browser if not installed

### Smart Learning
- After 3+ uses of the same request, AI builds a direct shortcut (skips UI scanning)

### Chat Management
- `!chat save [name]` — Save chat
- `!chat load <name>` — Load chat
- `!chat continue <name>` — Continue a saved chat
- `!chat list` — List saved chats
- `!chat export [name]` — Export as text
- `!chat clear` — Clear history
- `!chat config` — Show configuration

### Multi-Provider AI (25+ Providers)
| Provider | Type |
|----------|------|
| OpenRouter | Aggregator (hundreds of models) |
| OpenAI | GPT-4, GPT-4o |
| Anthropic | Claude Sonnet, Claude Opus |
| Google Gemini | Gemini 2.5 Flash |
| Cerebras | Ultra-fast inference |
| Groq | LPU hardware (100+ tok/s) |
| Fireworks AI | Low-latency open-source |
| Mistral AI | Open-weight models |
| Together AI | 200+ open-source models |
| DeepInfra | Cheap serverless |
| WaveSpeed AI | 290+ models, zero cold-start |
| AI/ML API | Unified portal |
| SiliconFlow | Global cost-efficient |
| Hugging Face | Free serverless API |
| Cohere, Replicate, Perplexity, DeepSeek, Ollama, LM Studio, Voyage AI, AI21 Labs, OctoAI, Anyscale, OpenWebUI | ...and more |

---

## Option 1: Termux CLI

### Install
```bash
pkg update && pkg upgrade
pkg install python git
git clone https://github.com/2ndaccforsmart-sys/zournia_mobile.git
cd zournia_mobile
```

### Run
```bash
python zournia_cli.py
```

### CLI Commands
| Command | Description |
|---------|-------------|
| `/chat` | Enter chat mode |
| `/model [name]` | Switch model |
| `/model key <provider> <key>` | Set API key |
| `/model add <name> <id>` | Add custom model |
| `/mode [default\|automation\|normal]` | Switch mode |
| `/telemetry` | Session diagnostics |
| `/help` | Show help |
| `!chat` | Chat management |
| `/exit` | Exit |

### Automation Commands (in chat)
```
EXECUTE: <command>        — Run any shell command
TAP: <x> <y>              — Tap at coordinates
SWIPE: <x1> <y1> <x2> <y2> [ms]  — Swipe gesture
TYPE: <text>              — Type text
NAV: <action>             — back, home, recents, enter, delete, tab, escape
SCREENSHOT:               — Take screenshot
DUMPUI:                   — Scan screen elements
SEARCH: <platform> <query> — YouTube, Spotify, Netflix, TikTok, etc.
CLOSE: <target>           — Kill process
```

### Quick Start
```bash
python zournia_cli.py
# Paste API key when prompted

# Enter chat mode
/chat

# Try these:
play despacito on YouTube
open Instagram
tap on the search bar
swipe up to scroll
go back
take a screenshot
what apps do I have installed
```

---

## Option 2: Android APK

### Build Locally
```bash
flutter pub get
flutter build apk --release
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

### Build via GitHub Actions
1. Push to GitHub
2. Go to **Actions** tab
3. Select **Build Zournia Mobile APK**
4. Download the artifact

---

## Configuration Files

| File | Purpose |
|------|---------|
| `api_keys.json` | API keys for all providers |
| `api_key.txt` | Legacy single-key file (synced with api_keys.json) |
| `custom_models.json` | Custom model definitions |
| `learned_patterns.json` | AI-learned shortcuts |
| `discovered_apps.json` | Scanned installed apps cache |
| `saved_chats/` | Saved chat histories |
| `session_state.json` | Active session state |

---

## Free Model Setup (No Card Required)

### Option A: OpenRouter Free
1. Sign up at [openrouter.ai](https://openrouter.ai)
2. Create an API key (no payment needed)
3. Run `python zournia_cli.py` and paste the key
4. The bot defaults to `FreeModel` (openrouter/free) — fully free

### Option B: Hugging Face (Free)
1. Sign up at [huggingface.co](https://huggingface.co)
2. Create a Read/Write access token
3. In Zournia CLI: `/model key "Hugging Face" <token>`
4. Switch model: `/model Hermes` or `/model Dolphin`

### Option C: Google Gemini (Free Tier)
1. Get API key from [Google AI Studio](https://aistudio.google.com/apikey)
2. In Zournia CLI: `/model key "Google Gemini" <key>`
3. Switch model: `/model Gemini`
4. Free tier: 1,500 requests/day

---

## How Phone Automation Works

1. You type: "open Instagram and like the first post"
2. AI scans the screen (`DUMPUI:`) to find UI elements
3. AI outputs `EXECUTE: monkey -p com.instagram.android 1` to open Instagram
4. AI outputs `DUMPUI:` again to see the new screen
5. AI outputs `TAP: 500 300` to tap the first post
6. Cursor animates to (500, 300) with human-like movement
7. Click ripple plays, `input tap 500 300` executes
8. After 3+ uses of the same pattern, AI learns a shortcut and skips scanning

---

## Architecture

```
zournia_mobile/
├── zournia_cli.py                    # Python CLI (Termux)
├── lib/
│   ├── main.dart                     # Flutter entry point
│   ├── features/
│   │   ├── shell/presentation/
│   │   │   └── zournia_shell.dart    # Main UI + AI logic + automation
│   │   ├── automation/
│   │   │   ├── data/
│   │   │   │   ├── phone_controller.dart  # Phone control + DUMPUI cache
│   │   │   │   └── app_scanner.dart       # Dynamic app discovery
│   │   │   └── presentation/
│   │   │       └── cursor_overlay.dart    # PC-style cursor
│   │   ├── ui_components/
│   │   │   └── dropdown_menu.dart
│   │   ├── dashboard/
│   │   └── workspace_router/
│   └── core/
│       ├── security/                 # Security jail (disabled)
│       ├── theme/                    # Dark/light theme
│       └── update/                   # Auto-updater
└── .github/workflows/
    └── build_apk.yml                 # CI/CD
```

---

## License

Internal project — not for redistribution.
