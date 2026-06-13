# Zournia Mobile — Termux & APK Port

A mobile-friendly adaptation of Zournia OS, optimized for deployment on mobile phones either as a native Android APK or as an interactive CLI application inside Termux.

## Features

- **Termux CLI Option (`zournia_cli.py`)**:
  - Direct execution of system automation commands inside the Termux shell.
  - Portable, zero-dependency Python script using standard libraries (no `pip install` required).
  - Diagnostic Telemetry Panel (`/telemetry` command) tracking session state and processes.
  - Interactive slash commands for model selection (`/model`) and chat mode toggling (`/mode`).
- **Android APK Option**:
  - Full Flutter UI styled with the Zournia premium dark design system.
  - Dynamic window and title bar controls hidden on mobile to avoid crashes.
  - Dynamic AI response system prompt adjusting to the Android context (using Linux shell tools instead of Windows utilities).
  - Secure local storage for API keys (`api_keys.json`) and custom models.
- **Git & CI/CD Ready**:
  - Pre-configured `.gitignore` excluding runtime session logs, caches, and secret keys.
  - GitHub Actions Workflow (`.github/workflows/build_apk.yml`) to automatically compile the APK on every push to your repository.

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

# Clone your published repository
git clone <YOUR_PUBLISHED_GITHUB_REPO_URL>
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

### Method A: Automated GitHub Actions (Recommended)
1. Push this folder to your GitHub repository.
2. Navigate to the **Actions** tab on your GitHub repository page.
3. Select the **Build Zournia Mobile APK** workflow.
4. Download the compiled `zournia-mobile-apk` artifact from the run details, transfer it to your phone, and install!

### Method B: Local Compilation
If you have the Flutter SDK and Android SDK installed on your machine:
```bash
# Get Flutter dependencies
flutter pub get

# Compile release APK
flutter build apk --release
```
The resulting APK will be saved at `build/app/outputs/flutter-apk/app-release.apk`.

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
