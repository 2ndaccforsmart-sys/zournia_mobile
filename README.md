# Zournia Mobile — Termux & APK Port

A mobile-friendly adaptation of Zournia OS, optimized for deployment on Android phones either as a native APK or as an interactive CLI application inside Termux.

## Features

- **Termux CLI Option (`zournia_cli.py`)**:
  - Direct execution of system automation commands inside the Termux shell.
  - Zero-dependency Python script using standard libraries (no external package installations needed).
  - Diagnostic Telemetry Panel (`/telemetry` command) tracking session state and processes.
  - Interactive slash commands for model selection (`/model`) and chat mode toggling (`/mode`).
- **Android APK Option**:
  - Full Flutter UI styled with the Zournia premium dark design system.
  - Dynamic window and title bar controls hidden on mobile to avoid layout issues.
  - Dynamic AI response system prompt adjusting to the Android context (using Linux shell tools instead of Windows utilities).
  - Secure local storage for API keys (`api_keys.json`) and custom models.
- **Unrestricted Control**:
  - Removed local security jail constraints in both Python and Flutter paths to allow unrestricted system execution.
- **Intelligent Package Checker & Browser Fallback**:
  - Automatically queries the device package manager (`pm list packages`/`pm path` with redirection to bypass SELinux restrictions) to verify if an app is installed.
  - Launches popular apps directly using targeted launch activities (ChatGPT, Discord, YouTube, Telegram, WhatsApp, Spotify, Settings, etc.).
  - Gracefully falls back to browser URL launch or Google Search in Chrome when the app is not installed on the device.
- **Improved URL & Search Handling**:
  - Handles space-containing search strings by encoding space characters as `%20` and using quote-aware regex.
- **Silent Launch Telemetry**:
  - Suppresses activity intent outputs and warnings to keep the conversation logs clean.
- **Git & CI/CD Ready**:
  - Updated GitHub Actions workflow (`.github/workflows/build_apk.yml`) leveraging the latest stable Flutter SDK.

---

## Option 1: Termux CLI (Fastest & Native Control)

To run Zournia natively on your phone inside the Termux terminal:

### 1. Installation
Open Termux on your phone and run:
```bash
# Update package list and upgrade existing tools
pkg update && pkg upgrade

# Install Python and Git
pkg install python git

# Clone the repository
git clone https://github.com/2ndaccforsmart-sys/zournia_mobile.git
cd zournia_mobile
```

### 2. Running the Client
Start the interactive client:
```bash
python zournia_cli.py
```
*On the first run, the client will prompt you to paste your OpenRouter API key. This key will be saved locally to `api_keys.json` and `api_key.txt` and is kept synchronized with the Flutter app.*

### 3. CLI Commands
- `/help` — Displays all available console commands.
- `/telemetry` — Prints active session states, process registry (PIDs), and Termux environment variables.
- `/model [name]` — Switches the active model (e.g. `Gemini`, `Qwen`, or custom).
- `/mode [default|automation]` — Toggles chat automation mode.
- `/exit` — Closes the terminal client.

---

## Option 2: Android APK App

You can compile the application to a native `.apk` file:

### Method A: Local Compilation (Recommended for instant access)
If you have the Flutter SDK and Android SDK installed on your machine:
```bash
# Get Flutter dependencies
flutter pub get

# Compile release APK
flutter build apk --release
```
The resulting APK will be saved at:
`build/app/outputs/flutter-apk/app-release.apk`
You can transfer this file directly to your phone and install it.

### Method B: Automated GitHub Actions
1. Push this folder to your GitHub repository.
2. Navigate to the **Actions** tab on your GitHub repository page.
3. Select the **Build Zournia Mobile APK** workflow.
4. Download the compiled `zournia-mobile-apk` artifact from the run details, transfer it to your phone, and install.

---

## Configuration Files

- `api_keys.json` — Stores your API keys securely.
- `custom_models.json` — Defines custom OpenRouter models to use in the dropdown or `/model` selector. Format:
  ```json
  [
    {
      "name": "Claude 3.5 Sonnet",
      "identifier": "anthropic/claude-3.5-sonnet",
      "provider": "OpenRouter"
    }
  ]
  ```

---

## Uncensored & Unrestricted Models (100% Free & Cardless Setup)

*Note: Together AI now requires a bank card deposit to activate its API. If you want a **100% free setup with zero credit cards, bank cards, or deposits**, follow the OpenRouter Free model setup below:*

### 1. Generate a Free OpenRouter API Key (No Card / No Deposit)
1. Go to [OpenRouter](https://openrouter.ai/) and sign up for an account (takes 5 seconds via Google, GitHub, or email).
2. Go to **Keys** in the top navigation -> click **Create Key** -> copy your new API Key.
*You do not need to add any payment methods or balance.*

### 2. Configure Your Key in Zournia CLI
1. Open Termux on your phone and run:
   ```bash
   python zournia_cli.py
   ```
2. When prompted, paste your OpenRouter key (or set it manually with `/model key openrouter <key>`).

### 3. Switch to FreeModel and Enable Automation
1. The bot is configured to run **FreeModel** (`openrouter/free`) by default on startup. This automatically routes requests to available free-tier models (like Llama 3 8B, Qwen 2.5, or Mistral 7B) completely for free.
2. Toggle automation mode:
   ```text
   /mode automation
   ```
*Our custom developer sandbox system prompts will run automatically to bypass standard alignment restrictions on Llama / Qwen models, giving you a fully unrestricted assistant for free!*

---

## Uncensored Dolphin & Hermes (100% Free & Cardless Setup)

If you specifically want **Dolphin** or **Hermes** uncensored models without setting up any cards/payments:

### 1. Get a Free Hugging Face API Token
1. Go to [Hugging Face](https://huggingface.co/) and sign up for a free account.
2. Go to **Settings -> Access Tokens** in your profile menu.
3. Click **Create New Token**, set the type to **Read** or **Write**, and copy the token (`hf_...`).
*Hugging Face's Serverless API is completely free and requires zero payment details.*

### 2. Configure Your Key in Zournia CLI
1. Open Termux on your phone and launch Zournia:
   ```bash
   python zournia_cli.py
   ```
2. Save your Hugging Face key:
   ```text
   /model key "Hugging Face" <YOUR_HF_TOKEN>
   ```

### 3. Switch to Dolphin or Hermes
1. Set the model to Hermes (routes to `NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO` on Hugging Face):
   ```text
   /model Hermes
   ```
2. Or set the model to Dolphin (routes to `cognitivecomputations/dolphin-2.6-mixtral-8x7b` on Hugging Face):
   ```text
   /model Dolphin
   ```
3. Set mode to automation:
   ```text
   /mode automation
   ```
*Zournia will automatically detect your Hugging Face key and route queries directly to Hugging Face's serverless endpoint for free.*
