#!/usr/bin/env python3
"""Zournia CLI — AI Phone Controller & Automation Suite (Termux)."""

import os
import sys
import json
import subprocess
import re
import webbrowser
import urllib.request
import urllib.error
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHAT_DIR = os.path.join(SCRIPT_DIR, "saved_chats")

# ── ANSI Colors ──────────────────────────────────────────────────────────────
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_RED = "\033[91m"
C_GREY = "\033[90m"
C_WHITE = "\033[97m"
C_CYAN = "\033[96m"
C_RESET = "\033[0m"

BANNER = f"""{C_GREEN}
   ███████  ██████  ██    ██ ██████  ███    ██ ██  █████
   ╚══███╔╝██╔═══██╗██║   ██║██╔══██╗████╗  ██║██ ██╔══██╗
     ███╔╝ ██║   ██║██║   ██║██████╔╝██╔██╗ ██║██║███████║
    ███╔╝  ██║   ██║██║   ██║██╔══██╗██║╚██╗██║██║██╔══██║
   ███████╗╚██████╔╝╚██████╔╝██║  ██║██║ ╚████║██║██║  ██║
   ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
                     {C_GREY}// TERMUX_CORE{C_RESET}
"""

DEFAULT_MODELS = {
    "Gemini": "google/gemini-2.5-flash",
    "Qwen": "qwen/qwen-2.5-coder-32b-instruct",
    "Dolphin": "cognitivecomputations/dolphin-2.9.2-qwen2-72b",
    "Hermes": "nousresearch/hermes-3-llama-3.1-8b",
    "FreeModel": "openrouter/free",
}

KNOWN_PLATFORMS = ["youtube", "spotify", "netflix", "tiktok", "google", "amazon", "twitch", "soundcloud"]

HOME_PAGES = {
    "youtube": "https://www.youtube.com",
    "spotify": "https://open.spotify.com",
    "netflix": "https://www.netflix.com",
    "tiktok": "https://www.tiktok.com",
    "google": "https://www.google.com",
    "amazon": "https://www.amazon.com",
    "twitch": "https://www.twitch.tv",
    "soundcloud": "https://soundcloud.com",
}

DEEP_LINKS = {
    "youtube": {
        "app_package": "com.google.android.youtube",
        "deep_link": "intent://search?q={query}#Intent;package=com.google.android.youtube;end",
        "web_url": "https://www.youtube.com/results?search_query={query}",
    },
    "spotify": {
        "app_package": "com.spotify.music",
        "deep_link": "spotify:search:{query}",
        "web_url": "https://open.spotify.com/search/{query}",
    },
    "netflix": {
        "app_package": "com.netflix.mediaclient",
        "deep_link": "nflx://search?q={query}",
        "web_url": "https://www.netflix.com/search?q={query}",
    },
    "tiktok": {
        "app_package": "com.zhiliaoapp.musically",
        "deep_link": "snssdk1128://search?keyword={query}",
        "web_url": "https://www.tiktok.com/search?q={query}",
    },
    "google": {"web_url": "https://www.google.com/search?q={query}"},
    "amazon": {
        "app_package": "com.amazon.mShop.android.shopping",
        "web_url": "https://www.amazon.com/s?k={query}",
    },
    "twitch": {
        "app_package": "tv.twitch.android.app",
        "web_url": "https://www.twitch.tv/search?term={query}",
    },
    "soundcloud": {
        "app_package": "com.soundcloud.android",
        "web_url": "https://soundcloud.com/search?q={query}",
    },
}

NAV_KEY_MAP = {
    "back": "KEYCODE_BACK",
    "home": "KEYCODE_HOME",
    "recents": "KEYCODE_APP_SWITCH",
    "enter": "KEYCODE_ENTER",
    "delete": "KEYCODE_DEL",
    "tab": "KEYCODE_TAB",
    "escape": "KEYCODE_ESCAPE",
    "power": "KEYCODE_POWER",
    "volume_up": "KEYCODE_VOLUME_UP",
    "volume_down": "KEYCODE_VOLUME_DOWN",
}

APP_LAUNCHERS = {
    "com.discord": {"launcher": "com.discord/.main.MainDefault", "url": "https://discord.com/app"},
    "com.google.android.youtube": {"launcher": "com.google.android.youtube/.app.honeycomb.Shell$HomeActivity", "url": "https://youtube.com"},
    "com.android.chrome": {"launcher": "com.android.chrome/com.google.android.apps.chrome.Main", "url": "https://google.com"},
    "com.whatsapp": {"launcher": "com.whatsapp/.Main", "url": "https://web.whatsapp.com"},
    "com.spotify.music": {"launcher": "com.spotify.music/.MainActivity", "url": "https://open.spotify.com"},
    "com.android.settings": {"launcher": "com.android.settings/.Settings", "url": "https://www.google.com/search?q=android+settings"},
    "com.instagram.android": {"launcher": "com.instagram.android/.activity.MainStartActivity", "url": "https://instagram.com"},
    "com.facebook.katana": {"launcher": "com.facebook.katana/.LoginActivity", "url": "https://facebook.com"},
    "com.google.android.gm": {"launcher": "com.google.android.gm/.ConversationListActivity", "url": "https://mail.google.com"},
    "com.google.android.apps.maps": {"launcher": "com.google.android.apps.maps/com.google.android.maps.MapsActivity", "url": "https://maps.google.com"},
    "com.telegram.messenger": {"launcher": "org.telegram.messenger/org.telegram.ui.LaunchActivity", "url": "https://web.telegram.org"},
    "org.telegram.messenger": {"launcher": "org.telegram.messenger/org.telegram.ui.LaunchActivity", "url": "https://web.telegram.org"},
    "com.openai.chatgpt": {"launcher": "com.openai.chatgpt/.MainActivity", "url": "https://chatgpt.com"},
    "com.github.android": {"launcher": "com.github.android/.MainActivity", "url": "https://github.com"},
    "com.netflix.mediaclient": {"launcher": "com.netflix.mediaclient/.ui.launcher.LauncherActivity", "url": "https://www.netflix.com"},
    "com.zhiliaoapp.musically": {"launcher": "com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity", "url": "https://www.tiktok.com"},
    "tv.twitch.android.app": {"launcher": "tv.twitch.android.app/.core.v2.router.LauncherRouterActivity", "url": "https://www.twitch.tv"},
    "com.soundcloud.android": {"launcher": "com.soundcloud.android/.activities.DrawerActivity", "url": "https://soundcloud.com"},
    "com.amazon.mShop.android.shopping": {"launcher": "com.amazon.mShop.android.shopping/com.amazon.mShop.android.shopping.MainActivity", "url": "https://www.amazon.com"},
    "com.google.android.apps.youtube.music": {"launcher": "com.google.android.apps.youtube.music/.activities.MusicActivity", "url": "https://music.youtube.com"},
    "com.plexapp.android": {"launcher": "com.plexapp.android/.activity.SplashActivity", "url": "https://app.plex.tv"},
}

LOCAL_APP_MAP = {
    "youtube": "com.google.android.youtube",
    "chrome": "com.android.chrome",
    "browser": "com.android.chrome",
    "whatsapp": "com.whatsapp",
    "instagram": "com.instagram.android",
    "facebook": "com.facebook.katana",
    "twitter": "com.twitter.android",
    "tiktok": "com.zhiliaoapp.musically",
    "spotify": "com.spotify.music",
    "netflix": "com.netflix.mediaclient",
    "telegram": "org.telegram.messenger",
    "discord": "com.discord",
    "settings": "com.android.settings",
    "maps": "com.google.android.apps.maps",
    "gmail": "com.google.android.gm",
    "github": "com.github.android",
    "chatgpt": "com.openai.chatgpt",
    "calculator": "com.google.android.calculator",
    "camera": "com.android.camera",
    "gallery": "com.google.android.apps.photos",
    "files": "com.google.android.apps.nbu.files",
    "phone": "com.google.android.dialer",
    "messages": "com.google.android.apps.messaging",
}


# ── Helpers ──────────────────────────────────────────────────────────────────

def _run(cmd, timeout=5, shell=False):
    """Run a subprocess and return (stdout, stderr, returncode)."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, shell=shell)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except FileNotFoundError as e:
        # If command not found, try with full path for common Android binaries
        if isinstance(cmd, list) and cmd:
            bin_name = os.path.basename(cmd[0])
            for prefix in ["/system/bin", "/vendor/bin"]:
                full = os.path.join(prefix, bin_name)
                if os.path.exists(full):
                    try:
                        r = subprocess.run([full] + cmd[1:], capture_output=True, text=True, timeout=timeout)
                        return r.stdout.strip(), r.stderr.strip(), r.returncode
                    except Exception:
                        pass
        return "", str(e), -1
    except Exception as e:
        return "", str(e), -1


def _is_package_installed(pkg):
    out, _, rc = _run(["pm", "path", pkg], timeout=3)
    if rc == 0 and "package:" in out:
        return True
    out, _, rc = _run("pm list packages 2>&1 </dev/null", shell=True, timeout=3)
    return rc == 0 and f"package:{pkg}" in out


def _encode_query(q):
    return q.replace(" ", "+").replace("&", "%26").replace("'", "%27")


def _input_command(cmd_args, timeout=5):
    """Run an input command with fallback methods for INJECT_EVENTS permission.
    Tries: direct input → su -c input → cmd input.
    Returns (stdout, stderr, returncode)."""
    # Method 1: Direct input (works on older Android or with ADB enabled)
    out, err, rc = _run(["input"] + cmd_args, timeout=timeout)
    if rc == 0:
        return out, err, rc
    # Check if it's the INJECT_EVENTS permission error
    if "INJECT_EVENTS" in err or "SecurityException" in err:
        # Method 2: Try via su (root)
        out2, err2, rc2 = _run(["su", "-c", " ".join(["input"] + cmd_args)], timeout=timeout)
        if rc2 == 0:
            return out2, err2, rc2
        # Method 3: Try cmd input (some devices allow this)
        out3, err3, rc3 = _run(["cmd", "input"] + cmd_args, timeout=timeout)
        if rc3 == 0:
            return out3, err3, rc3
        return out, err, rc  # Return original error
    return out, err, rc


# ── ZourniaCLI ───────────────────────────────────────────────────────────────

class ZourniaCLI:
    def __init__(self):
        self.api_keys = {}
        self.custom_models = []
        self.session_state = {"lastAction": "", "targetPid": None, "intentTracking": ""}
        self.chat_mode = "default"
        self.selected_model = "FreeModel"
        self.process_registry = {}
        self._pending_ai_instruction = None  # For compound commands (e.g. "open X and do Y")
        self.load_configs()

    # ── Config persistence ───────────────────────────────────────────────

    def load_configs(self):
        self._load_json("api_keys.json", "api_keys")
        if not self.api_keys.get("OpenRouter"):
            legacy = os.path.join(SCRIPT_DIR, "api_key.txt")
            if os.path.exists(legacy):
                try:
                    with open(legacy) as f:
                        key = f.read().strip()
                        if key:
                            self.api_keys["OpenRouter"] = key
                except Exception:
                    pass
        self._load_json("custom_models.json", "custom_models")
        self._load_session_state()

    def _load_json(self, filename, attr):
        path = os.path.join(SCRIPT_DIR, filename)
        if os.path.exists(path):
            try:
                with open(path) as f:
                    setattr(self, attr, json.load(f))
            except Exception as e:
                print(f"{C_RED}Error loading {filename}: {e}{C_RESET}")

    def _load_session_state(self):
        path = os.path.join(SCRIPT_DIR, "session_state.json")
        if os.path.exists(path):
            try:
                with open(path) as f:
                    saved = json.load(f)
                for k in ("lastAction", "targetPid", "intentTracking"):
                    if k in saved:
                        self.session_state[k] = saved[k]
                if "selected_model" in saved:
                    self.selected_model = saved["selected_model"]
                if "chat_mode" in saved:
                    self.chat_mode = saved["chat_mode"]
            except Exception:
                pass

    def save_configs(self):
        try:
            with open(os.path.join(SCRIPT_DIR, "api_keys.json"), "w") as f:
                json.dump(self.api_keys, f, indent=2)
            if "OpenRouter" in self.api_keys:
                with open(os.path.join(SCRIPT_DIR, "api_key.txt"), "w") as f:
                    f.write(self.api_keys["OpenRouter"])
        except Exception as e:
            print(f"{C_RED}Error saving api_keys.json: {e}{C_RESET}")

        try:
            data = dict(self.session_state)
            data["selected_model"] = self.selected_model
            data["chat_mode"] = self.chat_mode
            with open(os.path.join(SCRIPT_DIR, "session_state.json"), "w") as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

    # ── Model management ─────────────────────────────────────────────────

    def get_model_identifier(self):
        if self.selected_model in DEFAULT_MODELS:
            return DEFAULT_MODELS[self.selected_model]
        for m in self.custom_models:
            if m.get("name") == self.selected_model:
                return m.get("identifier", "google/gemini-2.5-flash")
        return "google/gemini-2.5-flash"

    def get_api_key(self):
        if self.api_keys.get("OpenRouter"):
            return self.api_keys["OpenRouter"]
        for val in self.api_keys.values():
            if val:
                return val
        return ""

    # ── System info ──────────────────────────────────────────────────────

    def get_system_info(self):
        home_dir = os.environ.get("HOME", "/data/data/com.termux/files/home")
        user = os.environ.get("USER", "u0_a0")
        return (
            "Active Environment Information:\n"
            f"- OS: Android / Termux\n"
            f"- USER: {user}\n"
            f"- HOME: {home_dir}\n\n"
            "Terminal Commands:\n"
            "- To run any terminal command: EXECUTE: <command>\n"
            "- Examples: EXECUTE: ls -la, EXECUTE: cat file.txt, EXECUTE: python script.py\n\n"
            "Opening Android Apps:\n"
            "- EXECUTE: monkey -p <package_name> 1\n"
            "  * Discord: monkey -p com.discord 1\n"
            "  * YouTube: monkey -p com.google.android.youtube 1\n"
            "  * Chrome: monkey -p com.android.chrome 1\n"
            "  * WhatsApp: monkey -p com.whatsapp 1\n"
            "  * Spotify: monkey -p com.spotify.music 1\n"
            "  * Netflix: monkey -p com.netflix.mediaclient 1\n"
            "  * TikTok: monkey -p com.zhiliaoapp.musically 1\n"
            "  * Settings: monkey -p com.android.settings 1\n\n"
            "Browser Commands:\n"
            "- ALWAYS use Chrome as the default browser.\n"
            "- Open URL in Chrome: EXECUTE: am start -a android.intent.action.VIEW -d \"<url>\" com.android.chrome\n"
            "- Search Google: EXECUTE: am start -a android.intent.action.VIEW -d \"https://www.google.com/search?q=<query>\" com.android.chrome\n\n"
            "Media Search & Playback (SEARCH: command):\n"
            "- SEARCH: <platform> <query>\n"
            f"- Platforms: {', '.join(KNOWN_PLATFORMS)}\n"
            "- If no platform specified, defaults to youtube.\n"
            "- Examples:\n"
            "  SEARCH: youtube despacito\n"
            "  SEARCH: spotify Bohemian Rhapsody\n"
            "  SEARCH: netflix Stranger Things\n"
            "  SEARCH: tiktok dance tutorial\n\n"
            "Phone Automation (controlling the screen directly):\n"
            "- TAP: <x> <y> — Tap at screen coordinates.\n"
            "- SWIPE: <x1> <y1> <x2> <y2> [duration_ms] — Swipe gesture.\n"
            "- TYPE: <text> — Type text using the keyboard.\n"
            "- NAV: <action> — back, home, recents, enter, delete, tab, escape, power, volume_up, volume_down\n"
            "- SCREENSHOT: — Take a screenshot.\n"
            "- DUMPUI: — Scan screen and list all UI elements with coordinates.\n"
            "- Workflow: DUMPUI: to see screen → TAP: x y to tap → SWIPE: to scroll\n"
        )

    # ── Command extraction ───────────────────────────────────────────────

    def _extract_commands(self, response):
        """Extract all automation commands from an AI response."""
        commands = []
        in_code_block = False

        for line in response.split("\n"):
            raw = line.strip()
            if raw.startswith("```"):
                in_code_block = not in_code_block
                continue

            check = raw.strip("`").strip()
            if not check:
                continue

            for prefix in ("EXECUTE:", "CLOSE:", "SEARCH:", "TAP:", "SWIPE:", "TYPE:", "NAV:", "SCREENSHOT:", "DUMPUI:", "VISION:", "OPENAPP:", "LAUNCH:"):
                if check.startswith(prefix):
                    payload = check[len(prefix):].strip().strip("`").strip()
                    kind = prefix.rstrip(":")
                    if payload or kind in ("SCREENSHOT", "DUMPUI", "VISION"):
                        commands.append((kind, payload))
                    break
            else:
                upper = check.upper()
                if upper == "DUMPUI":
                    commands.append(("DUMPUI", ""))
                elif upper == "VISION":
                    commands.append(("VISION", ""))
                elif upper == "SCREENSHOT":
                    commands.append(("SCREENSHOT", ""))
                elif upper.startswith("EXECUTE ") or upper.startswith("EXECUTE\t"):
                    cmd = check[len("EXECUTE"):].strip()
                    if cmd:
                        commands.append(("EXECUTE", cmd))
                elif upper.startswith("SEARCH ") or upper.startswith("SEARCH\t"):
                    query = check[len("SEARCH"):].strip()
                    if query:
                        commands.append(("SEARCH", query))
                elif upper.startswith("CLOSE ") or upper.startswith("CLOSE\t"):
                    target = check[len("CLOSE"):].strip()
                    if target:
                        commands.append(("CLOSE", target))

        return commands

    def clean_response(self, response):
        if not response:
            return ""
        cleaned = []
        for line in response.split("\n"):
            stripped = line.strip().strip("`").strip()
            if stripped.startswith(("EXECUTE:", "CLOSE:", "SEARCH:", "TAP:", "SWIPE:", "TYPE:", "NAV:", "SCREENSHOT:", "DUMPUI:", "VISION:", "OPENAPP:", "LAUNCH:")):
                continue
            if line.strip():
                cleaned.append(line)
        return "\n".join(cleaned).strip()

    # ── Local intent parser ──────────────────────────────────────────────

    def local_intent_parse(self, prompt):
        p = prompt.lower().strip()

        if re.match(r"^(go\s+back|press\s+back|back\s+button)", p):
            return self.phone_nav("back")
        if re.match(r"^(go\s+home|press\s+home|home\s+screen)", p):
            return self.phone_nav("home")
        if re.match(r"^(open\s+recents|recent\s+apps|switch\s+apps)", p):
            return self.phone_nav("recents")

        # Split at compound connectors to isolate the app name
        compound_split = re.split(r"\s+(?:and|then|after|now|also)\s+", p, maxsplit=1)
        app_part = compound_split[0]
        extra_part = compound_split[1] if len(compound_split) > 1 else None

        m = re.match(r"^(?:open|launch|start|run)\s+(.+)", app_part)
        if m:
            name = m.group(1).strip()
            if name.endswith(" app"):
                name = name[:-4].strip()
            name = re.sub(r"\s+(?:in|on|with)\s+chrome\s*$", "", name).strip()
            if name in LOCAL_APP_MAP:
                pkg = LOCAL_APP_MAP[name]
                if _is_package_installed(pkg):
                    _run(["monkey", "-p", pkg, "1"], timeout=5)
                    if extra_part:
                        # Compound command: app opened, store remaining for AI
                        self._pending_ai_instruction = extra_part
                        return f"Opened {name.title()}. Now: {extra_part}"
                    return f"Opened {name.title()}."
            if not extra_part:
                encoded = _encode_query(name)
                return self.open_url(f"https://www.google.com/search?q={encoded}")
            # If there's extra text and app wasn't found, fall through to AI
            return None

        m = re.match(r"^(?:close|kill|stop)\s+(.+)", p)
        if m:
            target = m.group(1).strip()
            if target.endswith(" app"):
                target = target[:-4].strip()
            return self.terminate_process(target)

        m = re.match(r"^(?:search|play|look\s+up|find|watch|listen\s+to)\s+(.+?)\s+on\s+(.+)", p)
        if m:
            return self.search_media(f"{m.group(2).strip().rstrip('.')} {m.group(1).strip()}")

        m = re.match(r"^(?:search|play|look\s+up|find|watch|listen\s+to)\s+(.+)", p)
        if m:
            encoded = _encode_query(m.group(1).strip())
            return self.open_url(f"https://www.google.com/search?q={encoded}")

        m = re.match(r"(?:open\s+)?youtube\s+(?:and\s+)?(?:search|look\s+up|find)\s+(.+)", p)
        if m:
            return self.search_media(f"youtube {m.group(1).strip()}")

        if re.match(r"(?:https?://|www\.)", p):
            url = p if p.startswith("http") else f"https://{p}"
            return self.open_url(url)

        return None

    # ── URL & app opening ────────────────────────────────────────────────

    def open_url(self, url):
        print(f"{C_YELLOW}Opening: {url}{C_RESET}")

        for method in [
            ["am", "start", "-a", "android.intent.action.VIEW", "-d", url, "com.android.chrome"],
            ["am", "start", "-a", "android.intent.action.VIEW", "-d", url],
            ["termux-open", url],
        ]:
            out, err, rc = _run(method, timeout=5)
            if rc == 0:
                return f"EXECUTION ACK: Opened {url}."

        try:
            if webbrowser.open(url):
                return f"EXECUTION ACK: Opened {url}."
        except Exception:
            pass

        return f"Failed to open {url}"

    def _launch_app(self, pkg):
        """Try to launch a package. Returns ACK string or None if not installed."""
        if not _is_package_installed(pkg):
            return None

        if pkg in APP_LAUNCHERS:
            launcher = APP_LAUNCHERS[pkg]["launcher"]
            out, err, rc = _run(["am", "start", "-n", launcher], timeout=5)
            if rc == 0:
                return f"Launched {pkg}."

        out, err, rc = _run(["cmd", "package", "resolve-activity", "--brief", pkg], timeout=3)
        if rc == 0:
            for line in out.split("\n"):
                if "/" in line and not line.startswith("priority="):
                    component = line.strip()
                    _run(["am", "start", "-n", component], timeout=5)
                    return f"Launched {pkg}."

        _run(["am", "start", "-n", f"{pkg}/.MainActivity"], timeout=5)
        return f"Launched {pkg} (fallback)."

    # ── Shell execution ──────────────────────────────────────────────────

    def execute_terminal_command(self, command):
        nested = command.strip().strip("`")
        for prefix, kind in [
            ("SEARCH:", "SEARCH"), ("TAP:", "TAP"), ("SWIPE:", "SWIPE"),
            ("TYPE:", "TYPE"), ("NAV:", "NAV"), ("SCREENSHOT:", "SCREENSHOT"),
            ("DUMPUI:", "DUMPUI"), ("VISION:", "VISION"),
        ]:
            if nested.startswith(prefix):
                payload = nested[len(prefix):].strip().strip("`").strip()
                return {
                    "SEARCH": lambda p: self.search_media(p),
                    "TAP": lambda p: self.phone_tap(p),
                    "SWIPE": lambda p: self.phone_swipe(p),
                    "TYPE": lambda p: self.phone_type(p),
                    "NAV": lambda p: self.phone_nav(p),
                    "SCREENSHOT": lambda _: self.phone_screenshot(),
                    "DUMPUI": lambda _: self.phone_dump_ui(),
                    "VISION": lambda _: self.phone_screenshot_vision(),
                }[kind](payload)

        url_match = re.search(r'"(https?://[^"]+)"', command)
        if not url_match:
            url_match = re.search(r"'(https?://[^']+)'", command)
        if not url_match:
            url_match = re.search(r"(https?://[^\s\"']+)", command)
        if url_match:
            return self.open_url(url_match.group(1).replace(" ", "%20"))

        launch_match = re.search(r"(?:am start|monkey -p)\s+([a-zA-Z0-9._]+)(?:\s+1)?$", command.strip())
        if launch_match:
            pkg = launch_match.group(1)
            result = self._launch_app(pkg)
            if result:
                return f"EXECUTION ACK: {result}"
            return f"EXECUTION ACK: App '{pkg}' is not installed on this device."

        print(f"{C_YELLOW}Executing: {command}{C_RESET}")
        try:
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            app_name = command.split()[0].split("/")[-1] if command.split() else "command"
            self.session_state["lastAction"] = f"EXECUTE: {command}"
            self.session_state["targetPid"] = process.pid
            self.process_registry[app_name] = process.pid
            self.save_configs()

            time.sleep(0.5)
            status = process.poll()
            if status is None:
                return f'EXECUTION ACK: Command "{command}" triggered successfully. Process: "{app_name}" (PID: {process.pid}) is running in background.'

            stdout, stderr = process.communicate()
            out_text = stdout.decode("utf-8", errors="replace")
            err_text = stderr.decode("utf-8", errors="replace")
            out_lines = [l for l in out_text.splitlines() if "Starting: Intent {" not in l]
            err_lines = [l for l in err_text.splitlines() if "Warning: Activity not started" not in l]
            output = ""
            if "\n".join(out_lines).strip():
                output += f"\n\nOutput:\n{''.join(out_lines).strip()}"
            if "\n".join(err_lines).strip():
                output += f"\n\nError:\n{''.join(err_lines).strip()}"
            return f'EXECUTION ACK: Command "{command}" executed successfully with status {status}.{output}'
        except Exception as e:
            return f"Failed to execute command: {e}"

    # ── Phone automation ─────────────────────────────────────────────────

    def phone_tap(self, args):
        parts = args.strip().split()
        if len(parts) < 2:
            return "TAP ERROR: Usage: TAP: <x> <y>"
        try:
            x, y = int(parts[0]), int(parts[1])
            out, err, rc = _input_command(["tap", str(x), str(y)])
            return f"TAP ACK: Tapped at ({x}, {y})." if rc == 0 else f"TAP ERROR: {err}"
        except Exception as e:
            return f"TAP ERROR: {e}"

    def phone_swipe(self, args):
        parts = args.strip().split()
        if len(parts) < 4:
            return "SWIPE ERROR: Usage: SWIPE: <x1> <y1> <x2> <y2> [duration_ms]"
        try:
            x1, y1, x2, y2 = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
            dur = int(parts[4]) if len(parts) > 4 else 300
            out, err, rc = _input_command(["swipe", str(x1), str(y1), str(x2), str(y2), str(dur)])
            return f"SWIPE ACK: Swiped from ({x1}, {y1}) to ({x2}, {y2}) in {dur}ms." if rc == 0 else f"SWIPE ERROR: {err}"
        except Exception as e:
            return f"SWIPE ERROR: {e}"

    def phone_type(self, text):
        if not text.strip():
            return "TYPE ERROR: Usage: TYPE: <text>"
        try:
            escaped = text.replace(" ", "%s").replace("'", "\\'")
            out, err, rc = _input_command(["text", escaped])
            return f'TYPE ACK: Typed "{text}".' if rc == 0 else f"TYPE ERROR: {err}"
        except Exception as e:
            return f"TYPE ERROR: {e}"

    def phone_nav(self, action):
        key = NAV_KEY_MAP.get(action.lower().strip())
        if not key:
            return f'NAV ERROR: Unknown action "{action}". Available: {", ".join(NAV_KEY_MAP.keys())}'
        try:
            out, err, rc = _input_command(["keyevent", key])
            return f"NAV ACK: Pressed {action} ({key})." if rc == 0 else f"NAV ERROR: {err}"
        except Exception as e:
            return f"NAV ERROR: {e}"

    def phone_screenshot(self):
        home = os.environ.get("HOME", "/data/data/com.termux/files/home")
        path = os.path.join(home, "tmp", "zournia_ss.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out, err, rc = _run(["screencap", "-p", path], timeout=5)
        if rc == 0 and os.path.exists(path) and os.path.getsize(path) > 0:
            return f"SCREENSHOT ACK: Saved to {path}"
        return f"SCREENSHOT ERROR: {err}"

    def phone_screenshot_vision(self):
        import base64

        home = os.environ.get("HOME", "/data/data/com.termux/files/home")
        path = os.path.join(home, "tmp", "zournia_ss.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)

        out, err, rc = _run(["screencap", "-p", path], timeout=5)
        if rc != 0 or not os.path.exists(path) or os.path.getsize(path) == 0:
            return "VISION ERROR: Screenshot failed"

        with open(path, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode("utf-8")
        os.remove(path)

        api_key = self.get_api_key()
        if not api_key:
            return "VISION ERROR: No API key configured"

        body = json.dumps({
            "model": "google/gemini-2.5-flash",
            "messages": [{"role": "user", "content": [
                {"type": "text", "text": "Look at this Android phone screenshot. List every visible UI element with its approximate center x,y coordinates. Return ONLY a JSON array like: [{\"text\":\"element name\",\"x\":540,\"y\":1200}]"},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}},
            ]}],
            "max_tokens": 1024,
        }).encode("utf-8")

        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            data=body,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json", "HTTP-Referer": "https://zournia.internal", "X-Title": "Zournia Vision"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as res:
                data = json.loads(res.read().decode("utf-8"))
                content = data["choices"][0]["message"]["content"]
                if content is None:
                    return "VISION ERROR: Empty model response"
                content = content.strip()
                if content.startswith("```"):
                    content = content.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
                elements = json.loads(content)
                return f"VISION ACK: Found {len(elements)} elements.\n{json.dumps(elements)}"
        except Exception as e:
            return f"VISION ERROR: {e}"

    def phone_dump_ui(self):
        import re as _re

        home = os.environ.get("HOME", "/data/data/com.termux/files/home")
        tmpdir = os.path.join(home, "tmp")
        os.makedirs(tmpdir, exist_ok=True)
        path = "/sdcard/zournia_ui.xml"

        # Method 1: cmd uiautomator
        env = dict(os.environ)
        env["TMPDIR"] = tmpdir
        for cmd in [["cmd", "uiautomator", "dump", path], ["uiautomator", "dump", path]]:
            out, err, rc = _run(cmd, timeout=10)
            if rc == 0 and os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8", errors="replace") as f:
                        xml = f.read()
                    if "<node" in xml:
                        return self._parse_ui_xml(xml)
                except Exception:
                    pass

        # Method 2: dumpsys window
        out, _, rc = _run(["dumpsys", "window", "windows"], timeout=5)
        if rc == 0 and out:
            return self._parse_dumpsys_windows(out)

        # Method 3: vision fallback
        return self.phone_screenshot_vision()

    def _parse_ui_xml(self, xml):
        bounds_re = re.compile(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        text_re = re.compile(r'text="([^"]*)"')
        node_re = re.compile(r"<node[^>]*>")
        bounds = []
        for match in node_re.finditer(xml):
            node = match.group(0)
            b = bounds_re.search(node)
            t = text_re.search(node)
            if b:
                bounds.append({
                    "x1": int(b.group(1)), "y1": int(b.group(2)),
                    "x2": int(b.group(3)), "y2": int(b.group(4)),
                    "text": t.group(1) if t else "",
                })
        return f"DUMPUI ACK: Found {len(bounds)} UI elements.\n{json.dumps(bounds)}"

    def _parse_dumpsys_windows(self, dumpsys):
        elements = []
        for name, x1, y1, x2, y2 in re.findall(
            r"Window #\d+ Window\{[a-f0-9]+ \w+\s+(\S+)\}:\s+mFrame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
            dumpsys,
        ):
            elements.append({"x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2), "text": name})
        if not elements:
            for x1, y1, x2, y2 in re.findall(r"mFrame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]", dumpsys):
                elements.append({"x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2), "text": "window"})
        return f"DUMPUI ACK: Found {len(elements)} windows.\n{json.dumps(elements)}"

    # ── Media search ─────────────────────────────────────────────────────

    def search_media(self, query):
        query = query.strip()
        parts = query.split(None, 1)
        platform = "youtube"
        search_term = query

        if parts and parts[0].lower() in KNOWN_PLATFORMS:
            platform = parts[0].lower()
            search_term = parts[1] if len(parts) > 1 else ""

        if not search_term.strip():
            return self.open_url(HOME_PAGES.get(platform, "https://www.google.com"))

        encoded = _encode_query(search_term)
        info = DEEP_LINKS.get(platform, DEEP_LINKS["google"])

        if "app_package" in info and _is_package_installed(info["app_package"]):
            if "deep_link" in info:
                result = self.open_url(info["deep_link"].format(query=encoded))
                if "Failed" not in result:
                    return f"Opened '{search_term}' on {platform.title()}."

        web_url = info.get("web_url", f"https://www.google.com/search?q={encoded}").format(query=encoded)
        return self.open_url(web_url)

    # ── Process termination ──────────────────────────────────────────────

    def terminate_process(self, target):
        target_lower = target.lower().strip()
        pid = None

        if target_lower.isdigit():
            pid = int(target_lower)
        elif target_lower in self.process_registry:
            pid = self.process_registry[target_lower]
        elif self.session_state["targetPid"] and target_lower in ("it", "process", "that process"):
            pid = self.session_state["targetPid"]

        if pid is not None:
            try:
                result = subprocess.run(["kill", "-9", str(pid)], capture_output=True, text=True)
                self.process_registry = {k: v for k, v in self.process_registry.items() if v != pid}
                if self.session_state["targetPid"] == pid:
                    self.session_state["targetPid"] = None
                self.session_state["lastAction"] = f"CLOSE: PID {pid}"
                self.save_configs()
                return f"EXECUTION ACK: Process with PID {pid} terminated.\n{result.stdout}\n{result.stderr}"
            except Exception as e:
                return f"Failed to terminate PID {pid}: {e}"

        try:
            result = subprocess.run(["pkill", "-f", target], capture_output=True, text=True)
            self.session_state["lastAction"] = f"CLOSE: {target}"
            self.session_state["targetPid"] = None
            self.save_configs()
            return f'EXECUTION ACK: "{target}" termination attempted.\n{result.stdout}\n{result.stderr}'
        except Exception:
            return f"Error: '{target}' is not running or not found."

    # ── Chat command handler ─────────────────────────────────────────────

    def handle_chat_command(self, arg, chat_history):
        if not arg.startswith("!chat"):
            return False

        parts = arg.split(maxsplit=2)
        sub = parts[1].lower() if len(parts) > 1 else "config"
        extra = parts[2].strip() if len(parts) > 2 else ""

        handlers = {
            "config": lambda: self._chat_config(chat_history),
            "save": lambda: self._chat_save(extra, chat_history),
            "load": lambda: self._chat_load(extra, chat_history),
            "list": lambda: self._chat_list(),
            "clear": lambda: self._chat_clear(chat_history),
            "export": lambda: self._chat_export(extra, chat_history),
            "delete": lambda: self._chat_delete(extra),
            "continue": lambda: self._chat_continue(extra, chat_history),
        }
        handler = handlers.get(sub, self._chat_help)
        handler()
        return True

    def _chat_config(self, chat_history):
        print(f"\n{C_WHITE}--- CHAT CONFIG ---{C_RESET}")
        print(f"  Model: {C_CYAN}{self.selected_model}{C_RESET} ({self.get_model_identifier()})")
        print(f"  Mode: {C_CYAN}{self.chat_mode}{C_RESET}")
        print(f"  History: {len(chat_history)} messages")
        print(f"  Processes: {len(self.process_registry)}")
        print(f"{C_WHITE}-------------------{C_RESET}\n")

    def _chat_save(self, name, chat_history):
        name = name if name else f"chat_{int(time.time())}"
        os.makedirs(CHAT_DIR, exist_ok=True)
        try:
            with open(os.path.join(CHAT_DIR, f"{name}.json"), "w") as f:
                json.dump({"history": chat_history, "model": self.selected_model, "mode": self.chat_mode}, f, indent=2)
            print(f"{C_GREEN}Chat saved to {name}{C_RESET}\n")
        except Exception as e:
            print(f"{C_RED}Error saving chat: {e}{C_RESET}\n")

    def _chat_load(self, name, chat_history):
        if not name:
            print(f"{C_RED}Usage: !chat load <name>{C_RESET}\n")
            return
        try:
            with open(os.path.join(CHAT_DIR, f"{name}.json")) as f:
                data = json.load(f)
            chat_history.clear()
            for role, text in data.get("history", []):
                chat_history.append((role, text))
            if "model" in data:
                self.selected_model = data["model"]
            if "mode" in data:
                self.chat_mode = data["mode"]
            print(f"{C_GREEN}Chat loaded from {name} ({len(chat_history)} messages){C_RESET}\n")
        except FileNotFoundError:
            print(f"{C_RED}Chat '{name}' not found.{C_RESET}\n")
        except Exception as e:
            print(f"{C_RED}Error loading chat: {e}{C_RESET}\n")

    def _chat_list(self):
        os.makedirs(CHAT_DIR, exist_ok=True)
        files = [f[:-5] for f in os.listdir(CHAT_DIR) if f.endswith(".json")]
        if files:
            print(f"\n{C_CYAN}Saved Chats:{C_RESET}")
            for name in sorted(files):
                print(f"  - {name}")
            print()
        else:
            print(f"{C_GREY}No saved chats found.{C_RESET}\n")

    def _chat_clear(self, chat_history):
        chat_history.clear()
        print(f"{C_GREEN}Chat history cleared.{C_RESET}\n")

    def _chat_export(self, name, chat_history):
        if not chat_history:
            print(f"{C_GREY}No chat history to export.{C_RESET}\n")
            return
        name = name if name else f"export_{int(time.time())}"
        os.makedirs(CHAT_DIR, exist_ok=True)
        try:
            with open(os.path.join(CHAT_DIR, f"{name}.txt"), "w", encoding="utf-8") as f:
                for role, text in chat_history:
                    label = "You" if role == "user" else "Zournia"
                    f.write(f"[{label}]\n{text}\n\n")
            print(f"{C_GREEN}Chat exported to {name}.txt{C_RESET}\n")
        except Exception as e:
            print(f"{C_RED}Error exporting chat: {e}{C_RESET}\n")

    def _chat_delete(self, name):
        if not name:
            print(f"{C_RED}Usage: !chat delete <name>{C_RESET}\n")
            return
        try:
            os.remove(os.path.join(CHAT_DIR, f"{name}.json"))
            print(f"{C_GREEN}Deleted chat '{name}'.{C_RESET}\n")
        except FileNotFoundError:
            print(f"{C_RED}Chat '{name}' not found.{C_RESET}\n")

    def _chat_continue(self, name, chat_history):
        if not name:
            print(f"{C_RED}Usage: !chat continue <name>{C_RESET}\n")
            return
        try:
            with open(os.path.join(CHAT_DIR, f"{name}.json")) as f:
                data = json.load(f)
            for role, text in data.get("history", []):
                chat_history.append((role, text))
            if "model" in data:
                self.selected_model = data["model"]
            if "mode" in data:
                self.chat_mode = data["mode"]
            print(f"{C_GREEN}Chat '{name}' continued ({len(chat_history)} total messages){C_RESET}\n")
        except FileNotFoundError:
            print(f"{C_RED}Chat '{name}' not found.{C_RESET}\n")
        except Exception as e:
            print(f"{C_RED}Error: {e}{C_RESET}\n")

    def _chat_help(self):
        print(f"\n{C_WHITE}Chat Commands:{C_RESET}")
        print(f"  {C_GREEN}!chat config{C_RESET}         Show current chat configuration")
        print(f"  {C_GREEN}!chat save [name]{C_RESET}    Save current chat")
        print(f"  {C_GREEN}!chat load <name>{C_RESET}    Load a saved chat")
        print(f"  {C_GREEN}!chat continue <name>{C_RESET} Continue a saved chat")
        print(f"  {C_GREEN}!chat list{C_RESET}           List all saved chats")
        print(f"  {C_GREEN}!chat export [name]{C_RESET}  Export chat as text")
        print(f"  {C_GREEN}!chat clear{C_RESET}          Clear chat history")
        print(f"  {C_GREEN}!chat delete <name>{C_RESET}  Delete a saved chat\n")

    # ── AI response ──────────────────────────────────────────────────────

    def get_ai_response(self, prompt, chat_history):
        provider = "OpenRouter"
        model_name = self.get_model_identifier()

        if self.selected_model not in DEFAULT_MODELS:
            for m in self.custom_models:
                if m.get("name") == self.selected_model:
                    provider = m.get("provider", "OpenRouter")
                    break
        elif self.selected_model == "Hermes":
            for key in ("Together AI", "Together", "DeepInfra", "Hugging Face", "Hugging", "HuggingFace", "hf", "huggingface"):
                if self.api_keys.get(key):
                    provider = "Hugging Face" if "hug" in key.lower() or key == "hf" else key
                    model_name = "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO" if "hug" in key.lower() or key == "hf" else "NousResearch/Hermes-3-Llama-3.1-8B"
                    break
        elif self.selected_model == "Dolphin":
            for key in ("Together AI", "Together", "DeepInfra", "Hugging Face", "Hugging", "HuggingFace", "hf", "huggingface"):
                if self.api_keys.get(key):
                    provider = "Hugging Face" if "hug" in key.lower() or key == "hf" else key
                    model_name = "dphn/dolphin-2.9.2-qwen2-72b" if "hug" in key.lower() or key == "hf" else "cognitivecomputations/dolphin-2.9.2-qwen2-72b"
                    break
        elif self.selected_model == "Gemini":
            for key in ("Google Gemini", "Gemini"):
                if self.api_keys.get(key):
                    provider = key
                    model_name = "gemini-2.5-flash"
                    break

        prov_lower = provider.lower().strip()
        url = "https://openrouter.ai/api/v1/chat/completions"
        prov_key = provider

        endpoint_map = [
            ("together", "Together AI", "https://api.together.xyz/v1/chat/completions"),
            ("deepinfra", "DeepInfra", "https://api.deepinfra.com/v1/chat/completions"),
            ("hugging", "Hugging Face", "https://router.huggingface.co/v1/chat/completions"),
            ("hf", "Hugging Face", "https://router.huggingface.co/v1/chat/completions"),
            ("gemini", "Google Gemini", "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"),
            ("google", "Google Gemini", "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"),
            ("openai", "OpenAI", "https://api.openai.com/v1/chat/completions"),
            ("cerebras", "Cerebras", "https://api.cerebras.ai/v1/chat/completions"),
            ("groq", "Groq", "https://api.groq.com/openai/v1/chat/completions"),
            ("fireworks", "Fireworks AI", "https://api.fireworks.ai/inference/v1/chat/completions"),
            ("anthropic", "Anthropic", "https://api.anthropic.com/v1/messages"),
            ("claude", "Anthropic", "https://api.anthropic.com/v1/messages"),
            ("mistral", "Mistral AI", "https://api.mistral.ai/v1/chat/completions"),
            ("wavespeed", "WaveSpeed AI", "https://api.wavespeed.ai/v1/chat/completions"),
            ("aiml", "AI/ML API", "https://api.aimlapi.com/v1/chat/completions"),
            ("siliconflow", "SiliconFlow", "https://api.siliconflow.cn/v1/chat/completions"),
        ]
        for keyword, key, endpoint in endpoint_map:
            if keyword in prov_lower:
                prov_key = key
                url = endpoint
                break

        api_key = self.api_keys.get(prov_key, "")
        if not api_key:
            api_key = self.api_keys.get("OpenRouter", "")
            url = "https://openrouter.ai/api/v1/chat/completions"
            model_name = self.get_model_identifier()

        if not api_key:
            return f"Error: API key for {prov_key} (or OpenRouter fallback) is not configured. Use /model key to set it."

        session_str = (
            f"Active Session State:\n"
            f"- LAST_ACTION: {self.session_state.get('lastAction') or 'None'}\n"
            f"- TARGET_PID: {self.session_state.get('targetPid') or 'None'}\n"
            f"- INTENT_TRACKING: {self.session_state.get('intentTracking') or 'None'}\n"
        )

        system_prompt = self._build_system_prompt(session_str)

        messages = [{"role": "system", "content": system_prompt}]
        for role, text in chat_history[-10:]:
            messages.append({"role": role, "content": text})
        messages.append({"role": "user", "content": prompt})

        body = json.dumps({"model": model_name, "messages": messages, "max_tokens": 1024}).encode("utf-8")
        req = urllib.request.Request(url, data=body, headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://zournia.internal",
            "X-Title": "Zournia OS",
        }, method="POST")

        try:
            with urllib.request.urlopen(req) as res:
                data = json.loads(res.read().decode("utf-8"))
                choices = data.get("choices", [])
                if choices:
                    content = choices[0]["message"]["content"]
                    return content if content else "Error: Model returned empty content."
                return "Error: Empty response choices returned from model."
        except urllib.error.HTTPError as e:
            return f"Error: Server returned status code {e.code} - {e.read().decode('utf-8', errors='replace')}"
        except Exception as e:
            return f"Network Error: {e}"

    def _build_system_prompt(self, session_str):
        sys_info = self.get_system_info()

        if self.chat_mode == "normal":
            return (
                f"You are Zournia, a friendly phone assistant. Talk naturally and informally.\n"
                f"Do NOT output any EXECUTE, SEARCH, CLOSE, TAP, SWIPE, TYPE, NAV, SCREENSHOT, or DUMPUI commands.\n"
                f"Just chat normally. Be helpful, concise, and casual.\n\n"
                f"{session_str}\n\n{sys_info}"
            )

        return (
            f"You are a function-calling tool. Given a user request, output the matching function call.\n"
            f"Reply with a very short confirmation, then on the next line output the function call.\n"
            f"CRITICAL: ALWAYS use Chrome as the default browser. For EXECUTE commands that open URLs, ALWAYS include 'com.android.chrome' at the end.\n"
            f"When the user asks to open an app, ALWAYS use OPENAPP: <name> — NEVER output a Google search URL for app launches.\n"
            f"Functions:\n"
            f"EXECUTE: <command>\n"
            f"OPENAPP: <name> — Launch an installed app (whatsapp, instagram, discord, etc.)\n"
            f"SEARCH: <platform> <query> (platforms: youtube, spotify, netflix, tiktok, google, amazon, twitch, soundcloud)\n"
            f"CLOSE: <name>\n"
            f"TAP: <x> <y>\n"
            f"SWIPE: <x1> <y1> <x2> <y2>\n"
            f"TYPE: <text>\n"
            f"NAV: <action> (back, home, recents, enter, delete, tab, escape, power, volume_up, volume_down)\n"
            f"SCREENSHOT:\n"
            f"DUMPUI:\n"
            f"VISION: - screenshot + AI vision, returns coordinates of all visible elements\n"
            f"Multiple functions can be output, one per line.\n\n"
            f"{session_str}\n\n{sys_info}"
        )

    # ── Permissions ──────────────────────────────────────────────────────

    def check_all_files_access(self):
        test_path = "/sdcard/.zournia_perm_test"
        try:
            with open(test_path, "w") as f:
                f.write("ok")
            os.remove(test_path)
            return True
        except Exception:
            return False

    def request_all_files_access(self):
        try:
            _run(["sh", "-c", "am start -a android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION -d package:com.termux"], timeout=5)
            print(f"{C_GREEN}Opened All Files Access permission page for Termux.{C_RESET}")
            print(f"{C_YELLOW}Please enable 'Allow access to manage all files' for Termux.{C_RESET}\n")
            return True
        except Exception:
            pass
        try:
            _run(["sh", "-c", "am start -a android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION"], timeout=5)
            print(f"{C_YELLOW}Opened All Files Access settings. Find Termux and enable the permission.{C_RESET}\n")
            return True
        except Exception:
            pass
        print(f"{C_RED}Could not open permission settings. Grant manually: Settings > Apps > Termux > All Files Access.{C_RESET}\n")
        return False

    # ── Main loop ────────────────────────────────────────────────────────

    def run(self):
        print(BANNER)

        if not self.check_all_files_access():
            print(f"{C_YELLOW}Termux does not have All Files Access permission.{C_RESET}")
            self.request_all_files_access()
            input(f"{C_GREEN}Press Enter after granting the permission to continue...{C_RESET}\n")

        if not self.get_api_key():
            print(f"{C_YELLOW}No OpenRouter API key found.{C_RESET}")
            key = input(f"{C_GREEN}Please enter your OpenRouter API key: {C_RESET}").strip()
            if key:
                self.api_keys["OpenRouter"] = key
                self.save_configs()
                print(f"{C_GREEN}API key saved.{C_RESET}\n")
            else:
                print(f"{C_RED}Error: API key cannot be empty. Exiting.{C_RESET}")
                return

        print(f"Active Model: {C_CYAN}{self.selected_model}{C_RESET} ({self.get_model_identifier()})")
        print(f"Chat Mode: {C_CYAN}{self.chat_mode}{C_RESET}")
        print(f"Type {C_GREEN}/help{C_RESET} to view commands.\n")

        chat_history = []
        in_chat = False

        while True:
            try:
                if in_chat:
                    in_chat = self._run_chat_loop(chat_history)
                else:
                    in_chat = self._run_workspace_loop(chat_history)
            except KeyboardInterrupt:
                print(f"\n{C_YELLOW}Use /exit to quit.{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}An error occurred: {e}{C_RESET}\n")

    def _run_chat_loop(self, chat_history):
        prompt = input(f"{C_CYAN}You > {C_RESET}").strip()
        if not prompt:
            return True

        if prompt.startswith("/"):
            cmd_parts = prompt.split(maxsplit=1)
            cmd = cmd_parts[0].lower()
            arg = cmd_parts[1].strip() if len(cmd_parts) > 1 else ""

            if cmd in ("/return", "/exit", "/quit"):
                if arg == "all":
                    print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
                    return False
                print(f"{C_GREEN}Returned to WORKSPACE_CORE.{C_RESET}\n")
                return False
            return True

        if prompt.startswith("!"):
            self.handle_chat_command(prompt, chat_history)
            return True

        # Local intent handling (fast path)
        if self.chat_mode != "normal":
            local_ack = self.local_intent_parse(prompt)
            if local_ack:
                print(f"{C_GREEN}zournia > {C_WHITE}{local_ack}{C_RESET}\n")
                chat_history.append(("user", prompt))
                chat_history.append(("assistant", local_ack))
                # Handle compound commands: if there's a pending AI instruction, process it
                if self._pending_ai_instruction:
                    pending = self._pending_ai_instruction
                    self._pending_ai_instruction = None
                    print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
                    response = self.get_ai_response(pending, chat_history)
                    print(" " * 20, end="\r")
                    display_response = self.clean_response(response)
                    print(f"{C_GREEN}zournia > {C_WHITE}{display_response}{C_RESET}\n")
                    chat_history.append(("user", pending))
                    chat_history.append(("assistant", response))
                    if self.chat_mode != "normal":
                        for kind, payload in self._extract_commands(response):
                            ack = self._execute_command(kind, payload)
                            print(f"{C_GREEN}{ack}{C_RESET}\n")
                            chat_history.append(("user", f"{kind} confirmation received.\n\n{ack}"))
                return True

        # AI response
        print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
        response = self.get_ai_response(prompt, chat_history)
        print(" " * 20, end="\r")

        display_response = self.clean_response(response)
        print(f"{C_GREEN}zournia > {C_WHITE}{display_response}{C_RESET}\n")
        chat_history.append(("user", prompt))
        chat_history.append(("assistant", response))

        if self.chat_mode != "normal":
            for kind, payload in self._extract_commands(response):
                ack = self._execute_command(kind, payload)
                print(f"{C_GREEN}{ack}{C_RESET}\n")
                chat_history.append(("user", f"{kind} confirmation received.\n\n{ack}"))

        return True

    def _run_workspace_loop(self, chat_history):
        prompt = input(f"{C_GREEN}ZOURNIA // WORKSPACE_CORE > {C_RESET}").strip()
        if not prompt:
            return True

        if prompt.startswith("/"):
            return self._handle_slash_command(prompt, chat_history)

        if prompt.startswith("!"):
            self.handle_chat_command(prompt, chat_history)
            return True

        # Local intent handling
        if self.chat_mode != "normal":
            local_ack = self.local_intent_parse(prompt)
            if local_ack:
                print(f"\n{C_CYAN}You > {C_WHITE}{prompt}{C_RESET}")
                print(f"{C_GREEN}zournia > {C_WHITE}{local_ack}{C_RESET}\n")
                chat_history.append(("user", prompt))
                chat_history.append(("assistant", local_ack))
                # Handle compound commands: if there's a pending AI instruction, process it
                if self._pending_ai_instruction:
                    pending = self._pending_ai_instruction
                    self._pending_ai_instruction = None
                    print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
                    response = self.get_ai_response(pending, chat_history)
                    print(" " * 20, end="\r")
                    display_response = self.clean_response(response)
                    print(f"{C_GREEN}zournia > {C_WHITE}{display_response}{C_RESET}\n")
                    chat_history.append(("user", pending))
                    chat_history.append(("assistant", response))
                    if self.chat_mode != "normal":
                        for kind, payload in self._extract_commands(response):
                            ack = self._execute_command(kind, payload)
                            print(f"{C_GREEN}{ack}{C_RESET}\n")
                            chat_history.append(("user", f"{kind} confirmation received.\n\n{ack}"))
                return True

        # AI response
        print(f"\n{C_CYAN}You > {C_WHITE}{prompt}{C_RESET}")
        print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
        response = self.get_ai_response(prompt, chat_history)
        print(" " * 20, end="\r")

        display_response = self.clean_response(response)
        print(f"{C_GREEN}zournia > {C_WHITE}{display_response}{C_RESET}\n")
        chat_history.append(("user", prompt))
        chat_history.append(("assistant", response))

        if self.chat_mode != "normal":
            for kind, payload in self._extract_commands(response):
                ack = self._execute_command(kind, payload)
                print(f"{C_GREEN}{ack}{C_RESET}\n")
                chat_history.append(("user", f"{kind} confirmation received.\n\n{ack}"))

        return True

    def _execute_command(self, kind, payload):
        dispatch = {
            "EXECUTE": self.execute_terminal_command,
            "CLOSE": self.terminate_process,
            "SEARCH": self.search_media,
            "TAP": self.phone_tap,
            "SWIPE": self.phone_swipe,
            "TYPE": self.phone_type,
            "NAV": self.phone_nav,
            "SCREENSHOT": lambda _: self.phone_screenshot(),
            "DUMPUI": lambda _: self.phone_dump_ui(),
            "VISION": lambda _: self.phone_screenshot_vision(),
            "OPENAPP": lambda p: self._openapp_command(p),
            "LAUNCH": lambda p: self._openapp_command(p),
        }
        try:
            return dispatch[kind](payload)
        except Exception as e:
            return f"{kind} ERROR: {e}"

    def _openapp_command(self, name):
        """Handle OPENAPP/LAUNCH command from AI response."""
        name = name.strip().lower()
        if name.endswith(" app"):
            name = name[:-4].strip()
        if name in LOCAL_APP_MAP:
            pkg = LOCAL_APP_MAP[name]
            if _is_package_installed(pkg):
                _run(["monkey", "-p", pkg, "1"], timeout=5)
                return f"EXECUTION ACK: Opened {name.title()}."
            return f"EXECUTION ACK: {name.title()} not installed. Use LISTAPPS to see available apps."
        # Try as package name directly
        if _is_package_installed(name):
            _run(["monkey", "-p", name, "1"], timeout=5)
            return f"EXECUTION ACK: Opened {name}."
        return f"EXECUTION ACK: Unknown app '{name}'. Use LISTAPPS to see available apps."

    def _handle_slash_command(self, prompt, chat_history):
        cmd_parts = prompt.split(maxsplit=1)
        cmd = cmd_parts[0].lower()
        arg = cmd_parts[1].strip() if len(cmd_parts) > 1 else ""

        if cmd in ("/exit", "/quit"):
            if arg == "all":
                print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
                return False
            print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
            return False

        if cmd == "/chat":
            print(f"\n{C_GREEN}Entered chat mode. Type /return to go back to WORKSPACE_CORE.{C_RESET}\n")
            return True

        if cmd == "/help":
            self._print_help()
            return True

        if cmd == "/permissions":
            self.request_all_files_access()
            return True

        if cmd == "/telemetry":
            self._print_telemetry()
            return True

        if cmd == "/model":
            self._handle_model_command(arg)
            return True

        if cmd == "/mode":
            if arg.lower() in ("default", "automation", "normal"):
                self.chat_mode = arg.lower()
                print(f"Chat mode set to: {C_CYAN}{self.chat_mode}{C_RESET}\n")
            else:
                print(f"Current mode: {C_CYAN}{self.chat_mode}{C_RESET}. Set with: /mode normal, /mode default, or /mode automation\n")
            return True

        if cmd == "/return":
            self.session_state["intentTracking"] = ""
            self.save_configs()
            print(f"{C_GREEN}Already at WORKSPACE_CORE.{C_RESET}\n")
            return True

        print(f"{C_RED}Unknown command. Type /help for assistance.{C_RESET}\n")
        return True

    def _print_help(self):
        print(f"\n{C_WHITE}Zournia CLI Commands:{C_RESET}")
        print(f"  {C_GREEN}/chat{C_RESET}             Enter chat mode")
        print(f"  {C_GREEN}/model{C_RESET}            Model manager (add/remove/switch/set keys)")
        print(f"  {C_GREEN}/mode [normal|default|automation]{C_RESET} Switch chat mode")
        print(f"  {C_GREEN}/return{C_RESET}           Return to WORKSPACE_CORE")
        print(f"  {C_GREEN}/telemetry{C_RESET}        Print environment diagnostics")
        print(f"  {C_GREEN}!chat{C_RESET}             Chat management (save/load/list/clear/export/config)")
        print(f"  {C_GREEN}/permissions{C_RESET}      Open All Files Access permission page")
        print(f"  {C_GREEN}/help{C_RESET}             Show this help menu")
        print(f"  {C_GREEN}/exit{C_RESET}             Return to WORKSPACE_CORE")
        print(f"  {C_GREEN}/exit all{C_RESET}         Exit Zournia completely\n")

    def _print_telemetry(self):
        print(f"\n{C_WHITE}--- TELEMETRY DIAGNOSTIC PANEL ---{C_RESET}")
        print(f"Model: {self.selected_model} ({self.get_model_identifier()})")
        print(f"Mode: {self.chat_mode}")
        print(f"API Key: {'Yes' if self.get_api_key() else 'No'}")
        print(f"Processes: {len(self.process_registry)}")
        for name, pid in self.process_registry.items():
            print(f"  - {name}: PID {pid}")
        print(f"Last Action: {self.session_state.get('lastAction')}")
        print(f"Target PID: {self.session_state.get('targetPid')}")
        print(f"{C_WHITE}----------------------------------{C_RESET}\n")

    def _handle_model_command(self, arg):
        if not arg:
            self._print_model_manager()
        elif arg.startswith("add "):
            self._model_add(arg[4:].strip())
        elif arg.startswith("remove "):
            self._model_remove(arg[7:].strip())
        elif arg.startswith("key "):
            self._model_set_key(arg[4:].strip())
        elif arg == "key":
            self._model_show_keys()
        else:
            self._model_switch(arg)

    def _print_model_manager(self):
        print(f"\n{C_WHITE}--- MODEL MANAGER ---{C_RESET}")
        print(f"\n{C_CYAN}Built-in Models:{C_RESET}")
        for name, ident in DEFAULT_MODELS.items():
            active = " [active]" if self.selected_model == name else ""
            print(f"  - {name} ({ident}){active}")
        if self.custom_models:
            print(f"\n{C_CYAN}Custom Models:{C_RESET}")
            for m in self.custom_models:
                active = " [active]" if self.selected_model == m.get("name") else ""
                print(f"  - {m.get('name')} ({m.get('identifier')}){active}")
        print(f"\n{C_CYAN}Commands:{C_RESET}")
        print(f"  {C_GREEN}/model <name>{C_RESET}            Switch active model")
        print(f"  {C_GREEN}/model add <name> <id>{C_RESET}   Add custom model")
        print(f"  {C_GREEN}/model remove <name>{C_RESET}     Remove a custom model")
        print(f"  {C_GREEN}/model key <provider> <key>{C_RESET} Set API key")
        print(f"  {C_GREEN}/model key{C_RESET}               Show API key status\n")

    def _model_add(self, args):
        parts = args.split(maxsplit=1)
        if len(parts) < 2:
            print(f"{C_RED}Usage: /model add <name> <identifier>{C_RESET}\n")
            return
        name, identifier = parts
        existing = [m for m in self.custom_models if m.get("name", "").lower() == name.lower()]
        if existing:
            existing[0]["identifier"] = identifier
            print(f"{C_GREEN}Updated model '{name}' to {identifier}.{C_RESET}\n")
        else:
            self.custom_models.append({"name": name, "identifier": identifier})
            print(f"{C_GREEN}Added model '{name}' ({identifier}).{C_RESET}\n")
        self.save_configs()

    def _model_remove(self, name):
        before = len(self.custom_models)
        self.custom_models = [m for m in self.custom_models if m.get("name", "").lower() != name.lower()]
        if len(self.custom_models) < before:
            if self.selected_model.lower() == name.lower():
                self.selected_model = "Gemini"
            self.save_configs()
            print(f"{C_GREEN}Removed model '{name}'. Switched to Gemini.{C_RESET}\n")
        else:
            print(f"{C_RED}Model '{name}' not found.{C_RESET}\n")

    def _model_set_key(self, raw):
        if raw.startswith('"'):
            end = raw.find('"', 1)
            if end == -1:
                end = raw.find(" ", 1)
            provider = raw[1:end].strip()
            key = raw[end + 1:].strip().strip('"').strip()
        else:
            key_parts = raw.split(maxsplit=1)
            if len(key_parts) < 2:
                print(f"{C_RED}Usage: /model key <provider> <key>{C_RESET}\n")
                return
            provider, key = key_parts[0].strip(), key_parts[1].strip()
        self.api_keys[provider] = key
        self.save_configs()
        print(f"{C_GREEN}API key for '{provider}' saved.{C_RESET}\n")

    def _model_show_keys(self):
        print(f"\n{C_CYAN}API Key Status:{C_RESET}")
        if not self.api_keys:
            print(f"  {C_GREY}No keys configured.{C_RESET}")
        for prov, key in self.api_keys.items():
            masked = key[:8] + "..." + key[-4:] if len(key) > 16 else key
            print(f"  {prov}: {masked}")
        print()

    def _model_switch(self, name):
        for k in DEFAULT_MODELS:
            if name.lower() == k.lower():
                self.selected_model = k
                print(f"Switched model to: {C_CYAN}{self.selected_model}{C_RESET}\n")
                return
        for m in self.custom_models:
            if name.lower() == m.get("name", "").lower():
                self.selected_model = m.get("name")
                print(f"Switched model to: {C_CYAN}{self.selected_model}{C_RESET}\n")
                return
        print(f"{C_RED}Model '{name}' not found. Use /model add to add it.{C_RESET}\n")


if __name__ == "__main__":
    cli = ZourniaCLI()
    cli.run()
