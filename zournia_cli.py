#!/usr/bin/env python3
import os
import sys
import json
import subprocess
import re
import webbrowser

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHAT_DIR = os.path.join(SCRIPT_DIR, "saved_chats")
import urllib.request
import urllib.error
import time

# Colors
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
    "FreeModel": "openrouter/free"
}

class ZourniaCLI:
    def __init__(self):
        self.api_keys = {}
        self.custom_models = []
        self.session_state = {"lastAction": "", "targetPid": None, "intentTracking": ""}
        self.chat_mode = "default"  # default or automation
        self.selected_model = "FreeModel"
        self.process_registry = {}  # appName -> PID
        
        self.load_configs()

    def load_configs(self):
        # Load API Keys
        api_keys_path = os.path.join(SCRIPT_DIR, "api_keys.json")
        if os.path.exists(api_keys_path):
            try:
                with open(api_keys_path, "r") as f:
                    self.api_keys = json.load(f)
            except Exception as e:
                print(f"{C_RED}Error loading api_keys.json: {e}{C_RESET}")
        
        # Load legacy / single key
        if "OpenRouter" not in self.api_keys or not self.api_keys["OpenRouter"]:
            api_key_path = os.path.join(SCRIPT_DIR, "api_key.txt")
            if os.path.exists(api_key_path):
                try:
                    with open(api_key_path, "r") as f:
                        key = f.read().strip()
                        if key:
                            self.api_keys["OpenRouter"] = key
                except Exception as e:
                    pass

        # Load Custom Models
        custom_models_path = os.path.join(SCRIPT_DIR, "custom_models.json")
        if os.path.exists(custom_models_path):
            try:
                with open(custom_models_path, "r") as f:
                    self.custom_models = json.load(f)
            except Exception as e:
                print(f"{C_RED}Error loading custom_models.json: {e}{C_RESET}")

        # Load Session State
        session_state_path = os.path.join(SCRIPT_DIR, "session_state.json")
        if os.path.exists(session_state_path):
            try:
                with open(session_state_path, "r") as f:
                    saved = json.load(f)
                    self.session_state = {k: v for k, v in saved.items() if k in ("lastAction", "targetPid", "intentTracking")}
                    if "selected_model" in saved:
                        self.selected_model = saved["selected_model"]
                    if "chat_mode" in saved:
                        self.chat_mode = saved["chat_mode"]
            except Exception as e:
                pass

    def handle_chat_command(self, arg: str, chat_history: list) -> bool:
        """Handle !chat commands. Returns True if handled."""
        if not arg.startswith("!chat"):
            return False

        parts = arg.split(maxsplit=2)
        sub = parts[1].lower() if len(parts) > 1 else "config"
        extra = parts[2].strip() if len(parts) > 2 else ""

        if sub == "config":
            print(f"\n{C_WHITE}--- CHAT CONFIG ---{C_RESET}")
            print(f"  Model: {C_CYAN}{self.selected_model}{C_RESET} ({self.get_model_identifier()})")
            print(f"  Mode: {C_CYAN}{self.chat_mode}{C_RESET}")
            print(f"  History: {len(chat_history)} messages")
            print(f"  Active Processes: {len(self.process_registry)}")
            print(f"  Session State: {self.session_state.get('lastAction', 'None')}")
            print(f"  API Keys: {', '.join(k for k, v in self.api_keys.items() if v)}")
            print(f"{C_WHITE}-------------------{C_RESET}\n")

        elif sub == "save":
            name = extra if extra else f"chat_{int(time.time())}"
            os.makedirs(CHAT_DIR, exist_ok=True)
            path = os.path.join(CHAT_DIR, f"{name}.json")
            try:
                with open(path, "w") as f:
                    json.dump({"history": chat_history, "model": self.selected_model, "mode": self.chat_mode}, f, indent=2)
                print(f"{C_GREEN}Chat saved to {path}{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}Error saving chat: {e}{C_RESET}\n")

        elif sub == "load":
            if not extra:
                print(f"{C_RED}Usage: !chat load <name>{C_RESET}\n")
                return True
            path = os.path.join(CHAT_DIR, f"{extra}.json")
            try:
                with open(path, "r") as f:
                    data = json.load(f)
                chat_history.clear()
                for role, text in data.get("history", []):
                    chat_history.append((role, text))
                if "model" in data:
                    self.selected_model = data["model"]
                if "mode" in data:
                    self.chat_mode = data["mode"]
                print(f"{C_GREEN}Chat loaded from {path} ({len(chat_history)} messages){C_RESET}\n")
            except FileNotFoundError:
                print(f"{C_RED}Chat '{extra}' not found.{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}Error loading chat: {e}{C_RESET}\n")

        elif sub == "list":
            os.makedirs(CHAT_DIR, exist_ok=True)
            files = [f[:-5] for f in os.listdir(CHAT_DIR) if f.endswith(".json")]
            if files:
                print(f"\n{C_CYAN}Saved Chats:{C_RESET}")
                for name in sorted(files):
                    print(f"  - {name}")
                print()
            else:
                print(f"{C_GREY}No saved chats found.{C_RESET}\n")

        elif sub == "clear":
            chat_history.clear()
            print(f"{C_GREEN}Chat history cleared.{C_RESET}\n")

        elif sub == "export":
            if not chat_history:
                print(f"{C_GREY}No chat history to export.{C_RESET}\n")
                return True
            name = extra if extra else f"export_{int(time.time())}"
            os.makedirs(CHAT_DIR, exist_ok=True)
            path = os.path.join(CHAT_DIR, f"{name}.txt")
            try:
                with open(path, "w", encoding="utf-8") as f:
                    for role, text in chat_history:
                        label = "You" if role == "user" else "Zournia"
                        f.write(f"[{label}]\n{text}\n\n")
                print(f"{C_GREEN}Chat exported to {path}{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}Error exporting chat: {e}{C_RESET}\n")

        elif sub == "delete":
            if not extra:
                print(f"{C_RED}Usage: !chat delete <name>{C_RESET}\n")
                return True
            path = os.path.join(CHAT_DIR, f"{extra}.json")
            try:
                os.remove(path)
                print(f"{C_GREEN}Deleted chat '{extra}'.{C_RESET}\n")
            except FileNotFoundError:
                print(f"{C_RED}Chat '{extra}' not found.{C_RESET}\n")

        elif sub == "continue":
            if not extra:
                print(f"{C_RED}Usage: !chat continue <name>{C_RESET}\n")
                return True
            path = os.path.join(CHAT_DIR, f"{extra}.json")
            try:
                with open(path, "r") as f:
                    data = json.load(f)
                for role, text in data.get("history", []):
                    chat_history.append((role, text))
                if "model" in data:
                    self.selected_model = data["model"]
                if "mode" in data:
                    self.chat_mode = data["mode"]
                print(f"{C_GREEN}Chat '{extra}' continued ({len(chat_history)} total messages){C_RESET}\n")
            except FileNotFoundError:
                print(f"{C_RED}Chat '{extra}' not found.{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}Error: {e}{C_RESET}\n")

        else:
            print(f"\n{C_WHITE}Chat Commands:{C_RESET}")
            print(f"  {C_GREEN}!chat config{C_RESET}         Show current chat configuration")
            print(f"  {C_GREEN}!chat save [name]{C_RESET}    Save current chat (auto-names if no name)")
            print(f"  {C_GREEN}!chat load <name>{C_RESET}    Load a saved chat")
            print(f"  {C_GREEN}!chat continue <name>{C_RESET} Continue a saved chat (append to current)")
            print(f"  {C_GREEN}!chat list{C_RESET}           List all saved chats")
            print(f"  {C_GREEN}!chat export [name]{C_RESET}  Export chat as readable text file")
            print(f"  {C_GREEN}!chat clear{C_RESET}          Clear current chat history")
            print(f"  {C_GREEN}!chat delete <name>{C_RESET}  Delete a saved chat\n")

        return True

    def save_configs(self):
        try:
            api_keys_path = os.path.join(SCRIPT_DIR, "api_keys.json")
            with open(api_keys_path, "w") as f:
                json.dump(self.api_keys, f, indent=2)
            
            # Legacy sync
            if "OpenRouter" in self.api_keys:
                api_key_path = os.path.join(SCRIPT_DIR, "api_key.txt")
                with open(api_key_path, "w") as f:
                    f.write(self.api_keys["OpenRouter"])
        except Exception as e:
            print(f"{C_RED}Error saving api_keys.json: {e}{C_RESET}")

        try:
            session_state_path = os.path.join(SCRIPT_DIR, "session_state.json")
            save_data = dict(self.session_state)
            save_data["selected_model"] = self.selected_model
            save_data["chat_mode"] = self.chat_mode
            with open(session_state_path, "w") as f:
                json.dump(save_data, f, indent=2)
        except Exception as e:
            pass

    def get_api_key(self):
        if self.api_keys.get("OpenRouter"):
            return self.api_keys["OpenRouter"]
        for val in self.api_keys.values():
            if val:
                return val
        return ""

    def validate_command(self, command: str) -> bool:
        return True

    def get_model_identifier(self):
        if self.selected_model in DEFAULT_MODELS:
            return DEFAULT_MODELS[self.selected_model]
        
        # Check custom models
        for m in self.custom_models:
            if m.get("name") == self.selected_model:
                return m.get("identifier", "google/gemini-2.5-flash")
                
        return "google/gemini-2.5-flash"

    def clean_response(self, response):
        if not response:
            return ""
        cleaned_lines = []
        for line in response.split("\n"):
            stripped = line.strip().strip("`").strip()
            if stripped.startswith(("EXECUTE:", "CLOSE:", "SEARCH:", "TAP:", "SWIPE:", "TYPE:", "NAV:", "SCREENSHOT:", "DUMPUI:", "VISION:")):
                continue
            for tag in ["EXECUTE:", "CLOSE:", "SEARCH:", "TAP:", "SWIPE:", "TYPE:", "NAV:", "SCREENSHOT:", "DUMPUI:", "VISION:"]:
                idx = line.find(tag)
                if idx > 0:
                    line = line[:idx].rstrip()
            if line.strip():
                cleaned_lines.append(line)
        return "\n".join(cleaned_lines).strip()

    def _strip_line(self, line: str) -> str:
        """Strip all markdown/code noise from a line."""
        return line.strip().strip("`").strip()

    def _extract_commands(self, response: str) -> list:
        """Extract all EXECUTE, CLOSE, SEARCH, TAP, SWIPE, TYPE, NAV, SCREENSHOT, DUMPUI commands from an AI response.
        Handles plain text, inline code, markdown code blocks, and commands with or without colon."""
        commands = []
        found_commands = set()
        in_code_block = False
        for line in response.split("\n"):
            raw = line.strip()
            if raw.startswith("```"):
                in_code_block = not in_code_block
                continue
            check = self._strip_line(line)
            if not check:
                continue

            if check.startswith("EXECUTE:"):
                cmd = check.replace("EXECUTE:", "", 1).strip().strip("`").strip()
                if cmd:
                    commands.append(("EXECUTE", cmd))
                    found_commands.add("EXECUTE")
            elif check.startswith("CLOSE:"):
                target = check.replace("CLOSE:", "", 1).strip().strip("`").strip()
                if target:
                    commands.append(("CLOSE", target))
                    found_commands.add("CLOSE")
            elif check.startswith("SEARCH:"):
                query = check.replace("SEARCH:", "", 1).strip().strip("`").strip()
                if query:
                    commands.append(("SEARCH", query))
                    found_commands.add("SEARCH")
            elif check.startswith("TAP:"):
                args = check.replace("TAP:", "", 1).strip().strip("`").strip()
                if args:
                    commands.append(("TAP", args))
                    found_commands.add("TAP")
            elif check.startswith("SWIPE:"):
                args = check.replace("SWIPE:", "", 1).strip().strip("`").strip()
                if args:
                    commands.append(("SWIPE", args))
                    found_commands.add("SWIPE")
            elif check.startswith("TYPE:"):
                text = check.replace("TYPE:", "", 1).strip().strip("`").strip()
                if text:
                    commands.append(("TYPE", text))
                    found_commands.add("TYPE")
            elif check.startswith("NAV:"):
                action = check.replace("NAV:", "", 1).strip().strip("`").strip()
                if action:
                    commands.append(("NAV", action))
                    found_commands.add("NAV")
            elif check.startswith("SCREENSHOT:"):
                commands.append(("SCREENSHOT", ""))
                found_commands.add("SCREENSHOT")
            elif check.startswith("DUMPUI:"):
                commands.append(("DUMPUI", ""))
                found_commands.add("DUMPUI")
            elif check.startswith("VISION:"):
                commands.append(("VISION", ""))
                found_commands.add("VISION")

        # Fallback: detect commands without colon (e.g. model outputs "DUMPUI" on its own line)
        if not commands:
            for line in response.split("\n"):
                check = self._strip_line(line).upper()
                if check == "DUMPUI":
                    commands.append(("DUMPUI", ""))
                elif check == "VISION":
                    commands.append(("VISION", ""))
                elif check == "SCREENSHOT":
                    commands.append(("SCREENSHOT", ""))
                elif check.startswith("EXECUTE ") or check.startswith("EXECUTE\t"):
                    cmd = self._strip_line(line[len("EXECUTE"):])
                    if cmd:
                        commands.append(("EXECUTE", cmd))
                elif check.startswith("SEARCH ") or check.startswith("SEARCH\t"):
                    query = self._strip_line(line[len("SEARCH"):])
                    if query:
                        commands.append(("SEARCH", query))
                elif check.startswith("CLOSE ") or check.startswith("CLOSE\t"):
                    target = self._strip_line(line[len("CLOSE"):])
                    if target:
                        commands.append(("CLOSE", target))

        return commands

    def get_system_info(self):
        home_dir = os.environ.get('HOME', '/data/data/com.termux/files/home')
        user = os.environ.get('USER', 'u0_a0')
        return (
            "Active Environment Information:\n"
            f"- OS: Android / Termux\n"
            f"- USER: {user}\n"
            f"- HOME: {home_dir}\n\n"
            "Terminal Commands:\n"
            "- To run any terminal command: EXECUTE: <command>\n"
            "- Examples: EXECUTE: ls -la, EXECUTE: cat file.txt, EXECUTE: python script.py\n\n"
            "Opening Android Apps:\n"
            "- To launch any installed Android app by its package name, use the 'monkey' tool: EXECUTE: monkey -p <package_name> 1\n"
            "  * Discord: monkey -p com.discord 1\n"
            "  * YouTube: monkey -p com.google.android.youtube 1\n"
            "  * Chrome: monkey -p com.android.chrome 1\n"
            "  * WhatsApp: monkey -p com.whatsapp 1\n"
            "  * Spotify: monkey -p com.spotify.music 1\n"
            "  * Netflix: monkey -p com.netflix.mediaclient 1\n"
            "  * TikTok: monkey -p com.zhiliaoapp.musically 1\n"
            "  * Settings: monkey -p com.android.settings 1\n"
            "  * Do NOT use 'am start <package_name>' directly as it will fail without the exact activity class path.\n\n"
            "Browser Commands:\n"
            "- To open a URL in a NEW Chrome tab: EXECUTE: am start -a android.intent.action.VIEW -d \"<url>\" com.android.chrome\n"
            "- To search Google: EXECUTE: am start -a android.intent.action.VIEW -d \"https://www.google.com/search?q=<query>\" com.android.chrome\n\n"
            "Media Search & Playback (SEARCH: command):\n"
            "- To search and play videos/music, use: SEARCH: <platform> <query>\n"
            "- Supported platforms: youtube, spotify, netflix, tiktok, google, amazon, twitch, soundcloud\n"
            "- If no platform specified, defaults to youtube.\n"
            "- Examples:\n"
            "  SEARCH: youtube despacito\n"
            "  SEARCH: spotify Bohemian Rhapsody\n"
            "  SEARCH: netflix Stranger Things\n"
            "  SEARCH: tiktok dance tutorial\n"
            "  SEARCH: twitch shroud\n"
            "  SEARCH: soundcloud lo-fi beats\n"
            "- When user says 'play X', 'watch X', 'search X on YouTube', 'listen to X' — use SEARCH: command.\n\n"
            "Phone Automation (controlling the screen directly):\n"
            "- TAP: <x> <y> — Tap at screen coordinates.\n"
            "- SWIPE: <x1> <y1> <x2> <y2> [duration_ms] — Swipe gesture.\n"
            "- TYPE: <text> — Type text using the keyboard.\n"
            "- NAV: <action> — back, home, recents, enter, delete, tab, escape, power, volume_up, volume_down\n"
            "- SCREENSHOT: — Take a screenshot.\n"
            "- DUMPUI: — Scan screen and list all UI elements with coordinates.\n"
            "- Workflow: DUMPUI: to see screen → TAP: x y to tap → SWIPE: to scroll\n"
        )

    def local_intent_parse(self, prompt: str) -> str:
        """Handle common requests locally without AI. Returns ack string or None."""
        import re as _re
        p = prompt.lower().strip()

        # Navigation
        if _re.match(r'^(go\s+back|press\s+back|back\s+button)', p):
            return self.phone_nav("back")
        if _re.match(r'^(go\s+home|press\s+home|home\s+screen)', p):
            return self.phone_nav("home")
        if _re.match(r'^(open\s+recents|recent\s+apps|switch\s+apps)', p):
            return self.phone_nav("recents")

        app_map = {
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

        # "open X" — open native app if installed, else Chrome
        m = _re.match(r'^(?:open|launch|start|run)\s+(.+)', p)
        if m:
            name = m.group(1).strip().rstrip(" app").strip()
            name = _re.sub(r'\s+(?:in|on|with)\s+chrome\s*$', '', name).strip()
            if name in app_map:
                pkg = app_map[name]
                try:
                    res = subprocess.run(
                        ["pm", "path", pkg],
                        capture_output=True, text=True, timeout=3
                    )
                    is_installed = "package:" in res.stdout and res.returncode == 0
                except Exception:
                    is_installed = False
                if is_installed:
                    result = subprocess.run(
                        ["monkey", "-p", pkg, "1"],
                        capture_output=True, text=True, timeout=5
                    )
                    if result.returncode == 0:
                        return f"Opened {name.title()}."

            # Not installed or not in map — search Google in Chrome
            encoded = name.replace(" ", "+")
            return self.open_url(f"https://www.google.com/search?q={encoded}")

        # "close X"
        m = _re.match(r'^(?:close|kill|stop)\s+(.+)', p)
        if m:
            target = m.group(1).strip().rstrip(" app").strip()
            return self.terminate_process(target)

        # "search/play/find/watch/listen X on Y" — always Chrome
        m = _re.match(r'^(?:search|play|look\s+up|find|watch|listen\s+to)\s+(.+?)\s+on\s+(.+)', p)
        if m:
            query = m.group(1).strip()
            platform = m.group(2).strip().rstrip(".")
            return self.search_media(f"{platform} {query}")

        # "search/play X" — default to Google in Chrome
        m = _re.match(r'^(?:search|play|look\s+up|find|watch|listen\s+to)\s+(.+)', p)
        if m:
            query = m.group(1).strip()
            encoded = query.replace(" ", "+")
            return self.open_url(f"https://www.google.com/search?q={encoded}")

        # "youtube search X" or "youtube X"
        m = _re.match(r'(?:open\s+)?youtube\s+(?:and\s+)?(?:search|look\s+up|find)\s+(.+)', p)
        if m:
            return self.search_media(f"youtube {m.group(1).strip()}")

        # Direct URL — only if it clearly starts with http or www
        if _re.match(r'(?:https?://|www\.)', p):
            url = p if p.startswith("http") else f"https://{p}"
            return self.open_url(url)

        return None

    def open_url(self, url: str) -> str:
        """Try every possible method to open a URL in the default browser."""
        print(f"{C_YELLOW}Opening: {url}{C_RESET}")

        # Method 1: am start without specifying package (uses default browser)
        try:
            r = subprocess.run(
                ["am", "start", "-a", "android.intent.action.VIEW", "-d", url],
                capture_output=True, text=True, timeout=5
            )
            if r.returncode == 0:
                return f"EXECUTION ACK: Opened {url}."
        except Exception:
            pass

        # Method 2: termux-open (uses Termux's default handler)
        try:
            r = subprocess.run(["termux-open", url], capture_output=True, text=True, timeout=5)
            if r.returncode == 0:
                return f"EXECUTION ACK: Opened {url}."
        except Exception:
            pass

        # Method 3: Python webbrowser
        try:
            if webbrowser.open(url):
                return f"EXECUTION ACK: Opened {url}."
        except Exception:
            pass

        # Method 4: Try Chrome as last resort
        try:
            r = subprocess.run(
                ["am", "start", "-a", "android.intent.action.VIEW", "-d", url, "com.android.chrome"],
                capture_output=True, text=True, timeout=5
            )
            if r.returncode == 0:
                return f"EXECUTION ACK: Opened {url} (via Chrome)."
        except Exception:
            pass

        return f"Failed to open {url}"

    def execute_terminal_command(self, command: str) -> str:
        if not self.validate_command(command):
            return "EXECUTION BLOCKED: Command execution is prohibited by Zournia Security Jail."

        # Intercept nested commands: if the payload starts with SEARCH:, TAP:, etc.
        # route to the correct handler instead of running as a shell command.
        nested_cmd = command.strip().strip("`")
        for prefix, kind in [("SEARCH:", "SEARCH"), ("TAP:", "TAP"), ("SWIPE:", "SWIPE"),
                             ("TYPE:", "TYPE"), ("NAV:", "NAV"), ("SCREENSHOT:", "SCREENSHOT"),
                             ("DUMPUI:", "DUMPUI")]:
            if nested_cmd.startswith(prefix):
                payload = nested_cmd[len(prefix):].strip().strip("`").strip()
                if kind == "SEARCH":
                    return self.search_media(payload)
                elif kind == "TAP":
                    return self.phone_tap(payload)
                elif kind == "SWIPE":
                    return self.phone_swipe(payload)
                elif kind == "TYPE":
                    return self.phone_type(payload)
                elif kind == "NAV":
                    return self.phone_nav(payload)
                elif kind == "SCREENSHOT":
                    return self.phone_screenshot()
                elif kind == "DUMPUI":
                    return self.phone_dump_ui()
                elif kind == "VISION":
                    return self.phone_screenshot_vision()

        # Intercept URL-opening commands and use the dedicated opener
        url_match = re.search(r'"(https?://[^"]+)"', command)
        if not url_match:
            url_match = re.search(r"'(https?://[^']+)'", command)
        if not url_match:
            url_match = re.search(r'(https?://[^\s"\']+)', command)
        if url_match:
            url_str = url_match.group(1).replace(" ", "%20")
            return self.open_url(url_str)

        # Intercept app launching commands
        launch_match = re.search(r'(?:am start|monkey -p)\s+([a-zA-Z0-9._]+)(?:\s+1)?$', command.strip())
        if launch_match:
            pkg = launch_match.group(1)
            popular_apps = {
                "com.discord": {
                    "launcher": "com.discord/.main.MainDefault",
                    "url": "https://discord.com/app"
                },
                "com.google.android.youtube": {
                    "launcher": "com.google.android.youtube/.app.honeycomb.Shell$HomeActivity",
                    "url": "https://youtube.com"
                },
                "com.android.chrome": {
                    "launcher": "com.android.chrome/com.google.android.apps.chrome.Main",
                    "url": "https://google.com"
                },
                "com.whatsapp": {
                    "launcher": "com.whatsapp/.Main",
                    "url": "https://web.whatsapp.com"
                },
                "com.spotify.music": {
                    "launcher": "com.spotify.music/.MainActivity",
                    "url": "https://open.spotify.com"
                },
                "com.android.settings": {
                    "launcher": "com.android.settings/.Settings",
                    "url": "https://www.google.com/search?q=android+settings"
                },
                "com.instagram.android": {
                    "launcher": "com.instagram.android/.activity.MainStartActivity",
                    "url": "https://instagram.com"
                },
                "com.facebook.katana": {
                    "launcher": "com.facebook.katana/.LoginActivity",
                    "url": "https://facebook.com"
                },
                "com.google.android.gm": {
                    "launcher": "com.google.android.gm/.ConversationListActivity",
                    "url": "https://mail.google.com"
                },
                "com.google.android.apps.maps": {
                    "launcher": "com.google.android.apps.maps/com.google.android.maps.MapsActivity",
                    "url": "https://maps.google.com"
                },
                "com.telegram.messenger": {
                    "launcher": "org.telegram.messenger/org.telegram.ui.LaunchActivity",
                    "url": "https://web.telegram.org"
                },
                "org.telegram.messenger": {
                    "launcher": "org.telegram.messenger/org.telegram.ui.LaunchActivity",
                    "url": "https://web.telegram.org"
                },
                "com.openai.chatgpt": {
                    "launcher": "com.openai.chatgpt/.MainActivity",
                    "url": "https://chatgpt.com"
                },
                "com.github.android": {
                    "launcher": "com.github.android/.MainActivity",
                    "url": "https://github.com"
                },
                "com.netflix.mediaclient": {
                    "launcher": "com.netflix.mediaclient/.ui.launcher.LauncherActivity",
                    "url": "https://www.netflix.com"
                },
                "com.zhiliaoapp.musically": {
                    "launcher": "com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity",
                    "url": "https://www.tiktok.com"
                },
                "tv.twitch.android.app": {
                    "launcher": "tv.twitch.android.app/.core.v2.router.LauncherRouterActivity",
                    "url": "https://www.twitch.tv"
                },
                "com.soundcloud.android": {
                    "launcher": "com.soundcloud.android/.activities.DrawerActivity",
                    "url": "https://soundcloud.com"
                },
                "com.amazon.mShop.android.shopping": {
                    "launcher": "com.amazon.mShop.android.shopping/com.amazon.mShop.android.shopping.MainActivity",
                    "url": "https://www.amazon.com"
                },
                "com.google.android.apps.youtube.music": {
                    "launcher": "com.google.android.apps.youtube.music/.activities.MusicActivity",
                    "url": "https://music.youtube.com"
                },
                "com.plexapp.android": {
                    "launcher": "com.plexapp.android/.activity.SplashActivity",
                    "url": "https://app.plex.tv"
                }
            }

            # Check if package is installed on the phone
            is_installed = False
            try:
                # 1. Try pm path (fast, checks one package)
                path_res = subprocess.run(
                    f"pm path {pkg} 2>&1 </dev/null",
                    shell=True, capture_output=True, text=True, timeout=3
                )
                if path_res.returncode == 0 and "package:" in path_res.stdout:
                    is_installed = True
                else:
                    # 2. Try pm list packages as fallback
                    res = subprocess.run(
                        "pm list packages 2>&1 </dev/null",
                        shell=True, capture_output=True, text=True, timeout=3
                    )
                    if res.returncode == 0:
                        is_installed = f"package:{pkg}" in res.stdout
            except Exception:
                is_installed = True

            if is_installed:
                if pkg in popular_apps:
                    command = f"am start -n {popular_apps[pkg]['launcher']}"
                else:
                    # Try to resolve activity using cmd package
                    try:
                        res = subprocess.run(
                            f"cmd package resolve-activity --brief {pkg}",
                            shell=True, capture_output=True, text=True, timeout=3
                        )
                        if res.returncode == 0:
                            lines = res.stdout.strip().splitlines()
                            if lines:
                                component = None
                                for line in lines:
                                    if "/" in line and not line.startswith("priority="):
                                        component = line.strip()
                                        break
                                    elif "/" in line:
                                        tokens = line.split()
                                        for token in tokens:
                                            if "/" in token:
                                                component = token.strip()
                                                break
                                if component:
                                    command = f"am start -n {component}"
                                else:
                                    command = f"am start -n {pkg}/.MainActivity"
                            else:
                                command = f"am start -n {pkg}/.MainActivity"
                        else:
                            command = f"am start -n {pkg}/.MainActivity"
                    except Exception:
                        command = f"am start -n {pkg}/.MainActivity"
            else:
                # App not installed: Redirect to browser
                fallback_url = popular_apps[pkg]["url"] if pkg in popular_apps else f"https://www.google.com/search?q={pkg.split('.')[-1]}"
                print(f"{C_YELLOW}App '{pkg}' not found on device. Launching fallback in browser...{C_RESET}")
                return self.open_url(fallback_url)

        print(f"{C_YELLOW}Executing: {command}{C_RESET}")
        try:
            tokens = command.split()
            app_name = tokens[0].split('/')[-1] if tokens else "command"

            process = subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            self.session_state["lastAction"] = f"EXECUTE: {command}"
            self.session_state["targetPid"] = process.pid
            self.process_registry[app_name] = process.pid
            self.save_configs()

            time.sleep(0.5)
            
            status = process.poll()
            if status is None:
                return f"EXECUTION ACK: Command \"{command}\" triggered successfully. Process: \"{app_name}\" (PID: {process.pid}) is running in background."
            else:
                stdout, stderr = process.communicate()
                out_text = stdout.decode('utf-8', errors='replace')
                err_text = stderr.decode('utf-8', errors='replace')

                # Filter out Android launcher / intent noise
                out_lines = [l for l in out_text.splitlines() if "Starting: Intent {" not in l]
                err_lines = [l for l in err_text.splitlines() if "Warning: Activity not started" not in l]
                out_clean = "\n".join(out_lines).strip()
                err_clean = "\n".join(err_lines).strip()
                
                output = ""
                if out_clean:
                    output += f"\n\nOutput:\n{out_clean}"
                if err_clean:
                    output += f"\n\nError:\n{err_clean}"
                
                return f"EXECUTION ACK: Command \"{command}\" executed successfully with status {status}.{output}"
        except Exception as e:
            return f"Failed to execute command: {e}"

    def phone_tap(self, args: str) -> str:
        """Tap at screen coordinates. Format: TAP: x y"""
        parts = args.strip().split()
        if len(parts) < 2:
            return "TAP ERROR: Usage: TAP: <x> <y>"
        try:
            x, y = int(parts[0]), int(parts[1])
            result = subprocess.run(["input", "tap", str(x), str(y)], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return f"TAP ACK: Tapped at ({x}, {y})."
            return f"TAP ERROR: {result.stderr}"
        except Exception as e:
            return f"TAP ERROR: {e}"

    def phone_swipe(self, args: str) -> str:
        """Swipe from one point to another. Format: SWIPE: x1 y1 x2 y2 [duration_ms]"""
        parts = args.strip().split()
        if len(parts) < 4:
            return "SWIPE ERROR: Usage: SWIPE: <x1> <y1> <x2> <y2> [duration_ms]"
        try:
            x1, y1, x2, y2 = int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
            dur = int(parts[4]) if len(parts) > 4 else 300
            result = subprocess.run(["input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur)], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                return f"SWIPE ACK: Swiped from ({x1}, {y1}) to ({x2}, {y2}) in {dur}ms."
            return f"SWIPE ERROR: {result.stderr}"
        except Exception as e:
            return f"SWIPE ERROR: {e}"

    def phone_type(self, text: str) -> str:
        """Type text. Format: TYPE: <text>"""
        if not text.strip():
            return "TYPE ERROR: Usage: TYPE: <text>"
        try:
            escaped = text.replace(" ", "%s").replace("'", "\\'")
            result = subprocess.run(["input", "text", escaped], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return f'TYPE ACK: Typed "{text}".'
            return f"TYPE ERROR: {result.stderr}"
        except Exception as e:
            return f"TYPE ERROR: {e}"

    def phone_nav(self, action: str) -> str:
        """Navigation actions. Format: NAV: <back|home|recents|enter|delete|tab|escape|power>"""
        key_map = {
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
        key = key_map.get(action.lower().strip())
        if not key:
            return f'NAV ERROR: Unknown action "{action}". Available: {", ".join(key_map.keys())}'
        try:
            result = subprocess.run(["input", "keyevent", key], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return f"NAV ACK: Pressed {action} ({key})."
            return f"NAV ERROR: {result.stderr}"
        except Exception as e:
            return f"NAV ERROR: {e}"

    def phone_screenshot(self) -> str:
        """Take a screenshot to Termux tmp (not /sdcard)."""
        path = os.path.join(os.environ.get("HOME", "/data/data/com.termux/files/home"), "tmp", "zournia_ss.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        try:
            result = subprocess.run(["screencap", "-p", path], capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and os.path.exists(path) and os.path.getsize(path) > 0:
                return f"SCREENSHOT ACK: Saved to {path}"
            return f"SCREENSHOT ERROR: {result.stderr}"
        except Exception as e:
            return f"SCREENSHOT ERROR: {e}"

    def phone_screenshot_vision(self) -> str:
        """Take a screenshot, send to vision model, return UI elements with coordinates. Fast and ephemeral."""
        import json as _json
        import base64
        home = os.environ.get("HOME", "/data/data/com.termux/files/home")
        tmpdir = os.path.join(home, "tmp")
        os.makedirs(tmpdir, exist_ok=True)
        path = os.path.join(tmpdir, "zournia_ss.png")
        try:
            subprocess.run(["screencap", "-p", path], capture_output=True, timeout=5)
            if not os.path.exists(path) or os.path.getsize(path) == 0:
                return "VISION ERROR: Screenshot failed"
            with open(path, "rb") as f:
                img_b64 = base64.b64encode(f.read()).decode("utf-8")
            os.remove(path)
        except Exception as e:
            return f"VISION ERROR: Screenshot: {e}"

        api_key = self.get_api_key()
        if not api_key:
            return "VISION ERROR: No API key configured"

        vision_prompt = (
            "Look at this Android phone screenshot. List every visible UI element with its approximate "
            "center x,y coordinates. Return ONLY a JSON array like: "
            '[{"text":"element name","x":540,"y":1200}] '
            "Include buttons, text fields, icons, tabs, labels. Be precise with coordinates."
        )

        body = json.dumps({
            "model": "google/gemini-2.5-flash",
            "messages": [
                {"role": "user", "content": [
                    {"type": "text", "text": vision_prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}}
                ]}
            ],
            "max_tokens": 1024
        }).encode("utf-8")

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://zournia.internal",
            "X-Title": "Zournia Vision",
        }

        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            data=body, headers=headers, method="POST"
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
                elements = _json.loads(content)
                return f"VISION ACK: Found {len(elements)} elements.\n{_json.dumps(elements)}"
        except Exception as e:
            return f"VISION ERROR: {e}"

    def phone_dump_ui(self) -> str:
        """Dump UI hierarchy using multiple methods."""
        import json as _json
        import re as _re
        path = "/sdcard/zournia_ui.xml"
        env = dict(os.environ)
        home = os.environ.get("HOME", "/data/data/com.termux/files/home")
        tmpdir = os.path.join(home, "tmp")
        env["TMPDIR"] = tmpdir
        os.makedirs(tmpdir, exist_ok=True)
        # Method 1: cmd uiautomator (uses Android framework, may bypass dalvik-cache)
        try:
            result = subprocess.run(
                ["cmd", "uiautomator", "dump", path],
                capture_output=True, text=True, timeout=10, env=env
            )
            if result.returncode == 0 and os.path.exists(path):
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    xml = f.read()
                if "<node" in xml:
                    return self._parse_ui_xml(xml)
        except Exception:
            pass
        # Method 2: uiautomator dump directly
        try:
            subprocess.run(["su", "-c", "mkdir -p /data/local/tmp/dalvik-cache"], capture_output=True, timeout=3)
        except Exception:
            pass
        try:
            result = subprocess.run(["uiautomator", "dump", path], capture_output=True, text=True, timeout=10, env=env)
            if result.returncode == 0 and os.path.exists(path):
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    xml = f.read()
                if "<node" in xml:
                    return self._parse_ui_xml(xml)
        except Exception:
            pass
        # Method 3: dumpsys window for basic window rectangles
        try:
            result = subprocess.run(["dumpsys", "window", "windows"], capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and result.stdout:
                return self._parse_dumpsys_windows(result.stdout)
        except Exception:
            pass
        # Method 4: vision fallback — screenshot + AI describes what it sees
        return self.phone_screenshot_vision()

    def _parse_ui_xml(self, xml: str) -> str:
        import json as _json
        import re as _re
        bounds_regex = _re.compile(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        text_regex = _re.compile(r'text="([^"]*)"')
        node_regex = _re.compile(r'<node[^>]*>')
        bounds = []
        for match in node_regex.finditer(xml):
            node = match.group(0)
            b = bounds_regex.search(node)
            t = text_regex.search(node)
            if b:
                bounds.append({
                    "x1": int(b.group(1)), "y1": int(b.group(2)),
                    "x2": int(b.group(3)), "y2": int(b.group(4)),
                    "text": t.group(1) if t else "",
                })
        return f"DUMPUI ACK: Found {len(bounds)} UI elements.\n{_json.dumps(bounds)}"

    def _parse_dumpsys_windows(self, dumpsys: str) -> str:
        """Parse dumpsys window for window rectangles."""
        import json as _json
        import re as _re
        elements = []
        window_matches = _re.findall(
            r'Window #\d+ Window\{[a-f0-9]+ \w+\s+(\S+)\}:\s+'
            r'mFrame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]',
            dumpsys
        )
        for name, x1, y1, x2, y2 in window_matches:
            elements.append({
                "x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2),
                "text": name,
            })
        if not elements:
            frame_matches = _re.findall(
                r'mFrame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]',
                dumpsys
            )
            for x1, y1, x2, y2 in frame_matches:
                elements.append({
                    "x1": int(x1), "y1": int(y1), "x2": int(x2), "y2": int(y2),
                    "text": "window",
                })
        return f"DUMPUI ACK: Found {len(elements)} windows.\n{_json.dumps(elements)}"

    def search_media(self, query: str) -> str:
        """Route a search query to the appropriate platform.
        Opens native app if installed, otherwise Chrome browser.
        Format: SEARCH: <platform> <query> or SEARCH: <query> (defaults to YouTube)
        Platforms: youtube, spotify, netflix, tiktok, google, amazon, twitch, soundcloud"""
        query = query.strip()
        parts = query.split(None, 1)
        platform = "youtube"
        search_term = query

        known_platforms = ["youtube", "spotify", "netflix", "tiktok", "google", "amazon", "twitch", "soundcloud"]
        if parts and parts[0].lower() in known_platforms:
            platform = parts[0].lower()
            search_term = parts[1] if len(parts) > 1 else ""

        if not search_term.strip():
            homepages = {
                "youtube": "https://www.youtube.com",
                "spotify": "https://open.spotify.com",
                "netflix": "https://www.netflix.com",
                "tiktok": "https://www.tiktok.com",
                "google": "https://www.google.com",
                "amazon": "https://www.amazon.com",
                "twitch": "https://www.twitch.tv",
                "soundcloud": "https://soundcloud.com",
            }
            return self.open_url(homepages.get(platform, "https://www.google.com"))

        encoded = search_term.replace(" ", "+").replace("&", "%26").replace("'", "%27")

        deep_links = {
            "youtube": {
                "app_package": "com.google.android.youtube",
                "deep_link": f"intent://search?q={encoded}#Intent;package=com.google.android.youtube;end",
                "web_url": f"https://www.youtube.com/results?search_query={encoded}",
            },
            "spotify": {
                "app_package": "com.spotify.music",
                "deep_link": f"spotify:search:{encoded}",
                "web_url": f"https://open.spotify.com/search/{encoded}",
            },
            "netflix": {
                "app_package": "com.netflix.mediaclient",
                "deep_link": f"nflx://search?q={encoded}",
                "web_url": f"https://www.netflix.com/search?q={encoded}",
            },
            "tiktok": {
                "app_package": "com.zhiliaoapp.musically",
                "deep_link": f"snssdk1128://search?keyword={encoded}",
                "web_url": f"https://www.tiktok.com/search?q={encoded}",
            },
            "google": {
                "web_url": f"https://www.google.com/search?q={encoded}",
            },
            "amazon": {
                "app_package": "com.amazon.mShop.android.shopping",
                "web_url": f"https://www.amazon.com/s?k={encoded}",
            },
            "twitch": {
                "app_package": "tv.twitch.android.app",
                "web_url": f"https://www.twitch.tv/search?term={encoded}",
            },
            "soundcloud": {
                "app_package": "com.soundcloud.android",
                "web_url": f"https://soundcloud.com/search?q={encoded}",
            },
        }

        info = deep_links.get(platform, deep_links["google"])

        # Check if native app is installed
        if "app_package" in info:
            pkg = info["app_package"]
            try:
                res = subprocess.run(
                    ["pm", "list", "packages"],
                    capture_output=True, text=True, timeout=3
                )
                is_installed = f"package:{pkg}" in res.stdout
            except Exception:
                is_installed = False

            if is_installed:
                # App is installed — open in native app via deep link
                if "deep_link" in info:
                    result = self.open_url(info["deep_link"])
                    if "Failed" not in result:
                        return f"Opened '{search_term}' on {platform.title()}."

        # Not installed or no deep link — open web URL in Chrome
        web_url = info.get("web_url", f"https://www.google.com/search?q={encoded}")
        return self.open_url(web_url)

    def terminate_process(self, target: str) -> str:
        target_lower = target.lower().strip()
        ack_msg = ""
        pid = None

        # Check if PID
        if target_lower.isdigit():
            pid = int(target_lower)
        elif target_lower in self.process_registry:
            pid = self.process_registry[target_lower]
        elif self.session_state["targetPid"] and target_lower in ["it", "process", "that process"]:
            pid = self.session_state["targetPid"]

        if pid is not None:
            try:
                # Run kill -9 PID
                result = subprocess.run(["kill", "-9", str(pid)], capture_output=True, text=True)
                # Remove from registry
                self.process_registry = {k: v for k, v in self.process_registry.items() if v != pid}
                if self.session_state["targetPid"] == pid:
                    self.session_state["targetPid"] = None
                self.session_state["lastAction"] = f"CLOSE: PID {pid}"
                self.save_configs()
                
                ack_msg = f"EXECUTION ACK: Process with PID {pid} terminated successfully.\n\nOutput:\n{result.stdout}\n{result.stderr}"
            except Exception as e:
                ack_msg = f"Failed to terminate process with PID {pid}: {e}"
        else:
            # Fallback to pkill
            try:
                result = subprocess.run(["pkill", "-f", target], capture_output=True, text=True)
                self.session_state["lastAction"] = f"CLOSE: {target}"
                self.session_state["targetPid"] = None
                self.save_configs()
                ack_msg = f"EXECUTION ACK: Application \"{target}\" termination by name attempted.\n\nOutput:\n{result.stdout}\n{result.stderr}"
            except Exception as e:
                ack_msg = f"Error: Application '{target}' is not running or not found."

        return ack_msg

    def get_ai_response(self, prompt: str, chat_history: list) -> str:
        # Determine provider and model identifier
        provider = "OpenRouter"
        model_name = self.get_model_identifier()
        
        # Check if custom model specifies provider
        if self.selected_model not in DEFAULT_MODELS:
            for m in self.custom_models:
                if m.get("name") == self.selected_model:
                    provider = m.get("provider", "OpenRouter")
                    break
        else:
            # For default models
            if self.selected_model == "Hermes":
                if self.api_keys.get("Together AI"):
                    provider = "Together AI"
                    model_name = "NousResearch/Hermes-3-Llama-3.1-8B"
                elif self.api_keys.get("Together"):
                    provider = "Together"
                    model_name = "NousResearch/Hermes-3-Llama-3.1-8B"
                elif self.api_keys.get("DeepInfra"):
                    provider = "DeepInfra"
                    model_name = "NousResearch/Hermes-3-Llama-3.1-8B"
                elif self.api_keys.get("Hugging Face") or self.api_keys.get("Hugging") or self.api_keys.get("HuggingFace"):
                    provider = "Hugging Face"
                    model_name = "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO"
                elif self.api_keys.get("hf") or self.api_keys.get("huggingface"):
                    provider = "Hugging Face"
                    model_name = "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO"
            elif self.selected_model == "Dolphin":
                if self.api_keys.get("Together AI"):
                    provider = "Together AI"
                    model_name = "cognitivecomputations/dolphin-2.9.2-qwen2-72b"
                elif self.api_keys.get("Together"):
                    provider = "Together"
                    model_name = "cognitivecomputations/dolphin-2.9.2-qwen2-72b"
                elif self.api_keys.get("DeepInfra"):
                    provider = "DeepInfra"
                    model_name = "cognitivecomputations/dolphin-2.9.2-qwen2-72b"
                elif self.api_keys.get("Hugging Face") or self.api_keys.get("Hugging") or self.api_keys.get("hf") or self.api_keys.get("huggingface") or self.api_keys.get("HuggingFace"):
                    provider = "Hugging Face"
                    model_name = "dphn/dolphin-2.9.2-qwen2-72b"
            elif self.selected_model == "Gemini":
                if self.api_keys.get("Google Gemini"):
                    provider = "Google Gemini"
                    model_name = "gemini-2.5-flash"
                elif self.api_keys.get("Gemini"):
                    provider = "Gemini"
                    model_name = "gemini-2.5-flash"

        # Resolve actual provider name and endpoint
        prov_key = provider
        url = "https://openrouter.ai/api/v1/chat/completions"
        
        prov_lower = provider.lower().strip()
        if "together" in prov_lower:
            prov_key = "Together AI" if "Together AI" in self.api_keys else ("Together" if "Together" in self.api_keys else "Together AI")
            url = "https://api.together.xyz/v1/chat/completions"
        elif "deepinfra" in prov_lower:
            prov_key = "DeepInfra"
            url = "https://api.deepinfra.com/v1/chat/completions"
        elif "huggingface" in prov_lower or "hugging face" in prov_lower or "hugging" in prov_lower or "hf" in prov_lower:
            prov_key = next((k for k in ["Hugging Face", "Hugging", "HuggingFace", "hf", "huggingface"] if k in self.api_keys), "Hugging Face")
            url = "https://router.huggingface.co/v1/chat/completions"
        elif "gemini" in prov_lower or "google" in prov_lower:
            prov_key = "Google Gemini" if "Google Gemini" in self.api_keys else ("Gemini" if "Gemini" in self.api_keys else "Google Gemini")
            url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        elif "openai" in prov_lower:
            prov_key = "OpenAI"
            url = "https://api.openai.com/v1/chat/completions"
        elif "cerebras" in prov_lower:
            prov_key = "Cerebras"
            url = "https://api.cerebras.ai/v1/chat/completions"
        elif "groq" in prov_lower:
            prov_key = "Groq"
            url = "https://api.groq.com/openai/v1/chat/completions"
        elif "fireworks" in prov_lower:
            prov_key = "Fireworks AI"
            url = "https://api.fireworks.ai/inference/v1/chat/completions"
        elif "anthropic" in prov_lower or "claude" in prov_lower:
            prov_key = "Anthropic"
            url = "https://api.anthropic.com/v1/messages"
        elif "mistral" in prov_lower:
            prov_key = "Mistral AI"
            url = "https://api.mistral.ai/v1/chat/completions"
        elif "wavespeed" in prov_lower:
            prov_key = "WaveSpeed AI"
            url = "https://api.wavespeed.ai/v1/chat/completions"
        elif "aiml" in prov_lower or "ai/ml" in prov_lower:
            prov_key = "AI/ML API"
            url = "https://api.aimlapi.com/v1/chat/completions"
        elif "siliconflow" in prov_lower:
            prov_key = "SiliconFlow"
            url = "https://api.siliconflow.cn/v1/chat/completions"

        api_key = self.api_keys.get(prov_key, "")
        # Fallback to OpenRouter key if specific key is empty
        if not api_key:
            api_key = self.api_keys.get("OpenRouter", "")
            url = "https://openrouter.ai/api/v1/chat/completions"
            model_name = self.get_model_identifier() # Reset to OpenRouter identifier

        if not api_key:
            return f"Error: API key for {prov_key} (or OpenRouter fallback) is not configured. Use /model key to set it."
        
        session_state_str = (
            f"Active Session State:\n"
            f"- LAST_ACTION: {self.session_state.get('lastAction') or 'None'}\n"
            f"- TARGET_PID: {self.session_state.get('targetPid') or 'None'}\n"
            f"- INTENT_TRACKING: {self.session_state.get('intentTracking') or 'None'}\n"
        )
        system_info_str = self.get_system_info()

        platform_name = "Android/Termux environment"
        shell_name = "Android shell"
        yt_example = "am start -a android.intent.action.VIEW -d \"https://youtube.com\" com.android.chrome"
        notepad_example = "ls -la"
        close_example = "'CLOSE: <process_name>' or 'EXECUTE: kill -9 <PID>'"
        taskkill_example = "kill -9 <TARGET_PID>"

        if self.chat_mode == "automation":
            system_prompt = (
                f"You are a function-calling tool. Given a user request, output the matching function call.\n"
                f"Reply with a very short confirmation, then on the next line output the function call.\n"
                f"Functions:\n"
                f"EXECUTE: <command>\n"
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
                f"{session_state_str}\n\n{system_info_str}"
            )
        elif self.chat_mode == "normal":
            system_prompt = (
                f"You are Zournia, a friendly phone assistant. Talk naturally and informally.\n"
                f"Do NOT output any EXECUTE, SEARCH, CLOSE, TAP, SWIPE, TYPE, NAV, SCREENSHOT, or DUMPUI commands.\n"
                f"Just chat normally. Be helpful, concise, and casual.\n\n"
                f"{session_state_str}\n\n{system_info_str}"
            )
        else:
            system_prompt = (
                f"You are a function-calling tool. Given a user request, output the matching function call.\n"
                f"Reply with a very short confirmation, then on the next line output the function call.\n"
                f"Functions:\n"
                f"EXECUTE: <command>\n"
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
                f"{session_state_str}\n\n{system_info_str}"
            )

        # Assemble messages payload
        messages_payload = [{"role": "system", "content": system_prompt}]
        for role, text in chat_history[-10:]:
            messages_payload.append({"role": role, "content": text})
        
        messages_payload.append({"role": "user", "content": prompt})

        # POST request using urllib.request
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://zournia.internal",
            "X-Title": "Zournia OS",
        }
        body = json.dumps({
            "model": model_name,
            "messages": messages_payload,
            "max_tokens": 1024,
        }).encode('utf-8')

        req = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req) as res:
                response_data = json.loads(res.read().decode('utf-8'))
                choices = response_data.get("choices", [])
                if choices:
                    content = choices[0]["message"]["content"]
                    if content is None:
                        return "Error: Model returned empty content."
                    return content
                return "Error: Empty response choices returned from model."
        except urllib.error.HTTPError as e:
            return f"Error: Server returned status code {e.code} - {e.read().decode('utf-8', errors='replace')}"
        except Exception as e:
            return f"Network Error: {e}"

    def request_all_files_access(self):
        """Open the All Files Access permission page for Termux."""
        try:
            # Try to open the MANAGE_EXTERNAL_STORAGE settings for Termux
            result = subprocess.run(
                ["sh", "-c", "am start -a android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION -d package:com.termux"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and "Error" not in result.stdout:
                print(f"{C_GREEN}Opened All Files Access permission page for Termux.{C_RESET}")
                print(f"{C_YELLOW}Please enable 'Allow access to manage all files' for Termux.{C_RESET}\n")
                return True
        except Exception:
            pass

        # Fallback: open generic MANAGE_ALL_FILES_ACCESS permission settings
        try:
            subprocess.run(
                ["sh", "-c", "am start -a android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION"],
                capture_output=True, text=True, timeout=5
            )
            print(f"{C_YELLOW}Opened All Files Access settings. Find Termux and enable the permission.{C_RESET}\n")
            return True
        except Exception:
            pass

        print(f"{C_RED}Could not open permission settings. Grant manually: Settings > Apps > Termux > All Files Access.{C_RESET}\n")
        return False

    def check_all_files_access(self) -> bool:
        """Check if Termux can actually write to external storage."""
        test_path = "/sdcard/.zournia_perm_test"
        try:
            with open(test_path, "w") as f:
                f.write("ok")
            os.remove(test_path)
            return True
        except Exception:
            return False

    def run(self):
        print(BANNER)

        # Auto-check and request All Files Access permission on startup
        if not self.check_all_files_access():
            print(f"{C_YELLOW}Termux does not have All Files Access permission.{C_RESET}")
            self.request_all_files_access()
            input(f"{C_GREEN}Press Enter after granting the permission to continue...{C_RESET}\n")

        # Guard API key check
        if not self.get_api_key():
            print(f"{C_YELLOW}No OpenRouter API key found.{C_RESET}")
            key = input(f"{C_GREEN}Please enter your OpenRouter API key: {C_RESET}").strip()
            if key:
                self.api_keys["OpenRouter"] = key
                self.save_configs()
                print(f"{C_GREEN}API key saved to api_keys.json and api_key.txt.{C_RESET}\n")
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
                    prompt = input(f"{C_CYAN}You > {C_RESET}").strip()
                    if not prompt:
                        continue

                    if prompt.startswith("/"):
                        cmd_parts = prompt.split(maxsplit=1)
                        cmd = cmd_parts[0].lower()
                        arg = cmd_parts[1].strip() if len(cmd_parts) > 1 else ""

                        if cmd == "/exit" and arg == "all":
                            print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
                            os.system("cd ~ && clear")
                            break

                        if cmd in ["/return", "/exit", "/quit"]:
                            in_chat = False
                            print(f"{C_GREEN}Returned to WORKSPACE_CORE.{C_RESET}\n")
                            continue

                    if prompt.startswith("!"):
                        self.handle_chat_command(prompt, chat_history)
                        continue

                    # Try local intent parser FIRST — fast, no AI needed
                    if self.chat_mode != "normal":
                        local_ack = self.local_intent_parse(prompt)
                        if local_ack:
                            print(f"{C_GREEN}zournia > {C_WHITE}{local_ack}{C_RESET}\n")
                            chat_history.append(("user", prompt))
                            chat_history.append(("assistant", local_ack))
                            continue

                    print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
                    response = self.get_ai_response(prompt, chat_history)
                    retries = 0
                    safety_words = ["user safety", "safety:", "i can't", "i cannot", "i'm not able", "i'm sorry", "i apologize", "not appropriate", "can't assist"]
                    while retries < 2 and (
                        response is None
                        or (isinstance(response, str) and response.strip() == "")
                        or (isinstance(response, str) and any(w in response.lower() for w in safety_words) and not any(c in response for c in ["EXECUTE:", "SEARCH:", "TAP:", "SWIPE:", "TYPE:", "NAV:", "CLOSE:", "SCREENSHOT:", "DUMPUI:"]))
                    ):
                        retries += 1
                        response = self.get_ai_response(prompt, chat_history)
                    print(" " * 20, end="\r")

                    display_response = self.clean_response(response)
                    print(f"{C_GREEN}zournia > {C_WHITE}{display_response}{C_RESET}\n")

                    chat_history.append(("user", prompt))
                    chat_history.append(("assistant", response))

                    if self.chat_mode != "normal":
                        commands_found = self._extract_commands(response)
                        for kind, payload in commands_found:
                            if kind == "EXECUTE":
                                ack = self.execute_terminal_command(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Execution confirmation received.\n\n{ack}"))
                            elif kind == "CLOSE":
                                ack = self.terminate_process(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Close confirmation received.\n\n{ack}"))
                            elif kind == "SEARCH":
                                ack = self.search_media(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Search confirmation received.\n\n{ack}"))
                            elif kind == "TAP":
                                ack = self.phone_tap(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Tap confirmation received.\n\n{ack}"))
                            elif kind == "SWIPE":
                                ack = self.phone_swipe(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Swipe confirmation received.\n\n{ack}"))
                            elif kind == "TYPE":
                                ack = self.phone_type(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Type confirmation received.\n\n{ack}"))
                            elif kind == "NAV":
                                ack = self.phone_nav(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Nav confirmation received.\n\n{ack}"))
                            elif kind == "SCREENSHOT":
                                ack = self.phone_screenshot()
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Screenshot confirmation received.\n\n{ack}"))
                            elif kind == "DUMPUI":
                                ack = self.phone_dump_ui()
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"UI dump confirmation received.\n\n{ack}"))
                            elif kind == "VISION":
                                ack = self.phone_screenshot_vision()
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Vision confirmation received.\n\n{ack}"))

                else:
                    prompt = input(f"{C_GREEN}ZOURNIA // WORKSPACE_CORE > {C_RESET}").strip()
                    if not prompt:
                        continue

                    if prompt.startswith("/"):
                        print()
                        print(f"{C_CYAN}You > {C_WHITE}{prompt}{C_RESET}")
                        cmd_parts = prompt.split(maxsplit=1)
                        cmd = cmd_parts[0].lower()
                        arg = cmd_parts[1].strip() if len(cmd_parts) > 1 else ""

                        if cmd in ["/exit", "/quit"]:
                            if arg == "all":
                                print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
                                os.system("cd ~ && clear")
                            else:
                                print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
                            break
                        
                        elif cmd == "/chat":
                            in_chat = True
                            print(f"\n{C_GREEN}Entered chat mode. Type /return to go back to WORKSPACE_CORE.{C_RESET}\n")
                        
                        elif cmd == "/help":
                            print(f"\n{C_WHITE}Zournia CLI Commands:{C_RESET}")
                            print(f"  {C_GREEN}/chat{C_RESET}             Enter chat mode (You > prompt).")
                            print(f"  {C_GREEN}/model{C_RESET}              Model manager (add/remove/switch/set keys)")
                            print(f"  {C_GREEN}/mode [normal|default|automation]{C_RESET} Switch chat mode.")
                            print(f"  {C_GREEN}/return{C_RESET}           Return to WORKSPACE_CORE.")
                            print(f"  {C_GREEN}/telemetry{C_RESET}        Print active environment diagnostics panel.")
                            print(f"  {C_GREEN}!chat{C_RESET}             Chat management (save/load/list/clear/export/config)")
                            print(f"  {C_GREEN}/permissions{C_RESET}       Open All Files Access permission page for Termux")
                            print(f"  {C_GREEN}/help{C_RESET}             Show this help menu.")
                            print(f"  {C_GREEN}/exit{C_RESET}             Return to WORKSPACE_CORE.")
                            print(f"  {C_GREEN}/exit all{C_RESET}         Exit Zournia completely.\n")
                        
                        elif cmd == "/permissions":
                            self.request_all_files_access()

                        elif cmd == "/telemetry":
                            print(f"\n{C_WHITE}--- TELEMETRY DIAGNOSTIC PANEL ---{C_RESET}")
                            print(f"Model Selection: {self.selected_model} ({self.get_model_identifier()})")
                            print(f"Chat Mode: {self.chat_mode}")
                            print(f"API Key Installed: {'Yes' if self.get_api_key() else 'No'}")
                            print(f"Process Registry: {len(self.process_registry)} active process(es)")
                            for name, pid in self.process_registry.items():
                                print(f"  - {name}: PID {pid}")
                            print(f"Session State:")
                            print(f"  - Last Action: {self.session_state.get('lastAction')}")
                            print(f"  - Target PID: {self.session_state.get('targetPid')}")
                            print(f"  - Intent Tracking: {self.session_state.get('intentTracking')}")
                            print(f"Environment Telemetry:")
                            print(self.get_system_info().strip())
                            print(f"{C_WHITE}----------------------------------{C_RESET}\n")

                        elif cmd == "/model":
                            if not arg:
                                print(f"\n{C_WHITE}--- MODEL MANAGER ---{C_RESET}")
                                print(f"\n{C_CYAN}Built-in Models:{C_RESET}")
                                print(f"  - Gemini (google/gemini-2.5-flash) {'[active]' if self.selected_model == 'Gemini' else ''}")
                                print(f"  - Qwen (qwen/qwen-2.5-coder-32b-instruct) {'[active]' if self.selected_model == 'Qwen' else ''}")
                                if self.custom_models:
                                    print(f"\n{C_CYAN}Custom Models:{C_RESET}")
                                    for m in self.custom_models:
                                        name = m.get("name")
                                        id_ = m.get("identifier")
                                        print(f"  - {name} ({id_}) {'[active]' if self.selected_model == name else ''}")
                                print(f"\n{C_CYAN}Commands:{C_RESET}")
                                print(f"  {C_GREEN}/model <name>{C_RESET}              Switch active model")
                                print(f"  {C_GREEN}/model add <name> <id>{C_RESET}     Add custom model (e.g. /model add llama meta-llama/llama-3-70b-instruct)")
                                print(f"  {C_GREEN}/model remove <name>{C_RESET}       Remove a custom model")
                                print(f"  {C_GREEN}/model key <provider> <key>{C_RESET} Set API key (e.g. /model key openrouter sk-or-v1-xxx)")
                                print(f"  {C_GREEN}/model key{C_RESET}                 Show API key status")
                                print()
                            elif arg.startswith("add "):
                                parts = arg[4:].strip().split(maxsplit=1)
                                if len(parts) < 2:
                                    print(f"{C_RED}Usage: /model add <name> <identifier>{C_RESET}")
                                    print(f"Example: /model add llama meta-llama/llama-3-70b-instruct\n")
                                else:
                                    name = parts[0]
                                    identifier = parts[1]
                                    existing = [m for m in self.custom_models if m.get("name", "").lower() == name.lower()]
                                    if existing:
                                        existing[0]["identifier"] = identifier
                                        print(f"{C_GREEN}Updated model '{name}' to {identifier}.{C_RESET}\n")
                                    else:
                                        self.custom_models.append({"name": name, "identifier": identifier})
                                        print(f"{C_GREEN}Added model '{name}' ({identifier}).{C_RESET}\n")
                                    self.save_configs()
                            elif arg.startswith("remove "):
                                name = arg[7:].strip()
                                before = len(self.custom_models)
                                self.custom_models = [m for m in self.custom_models if m.get("name", "").lower() != name.lower()]
                                if len(self.custom_models) < before:
                                    if self.selected_model.lower() == name.lower():
                                        self.selected_model = "Gemini"
                                    self.save_configs()
                                    print(f"{C_GREEN}Removed model '{name}'. Switched to Gemini.{C_RESET}\n")
                                else:
                                    print(f"{C_RED}Model '{name}' not found.{C_RESET}\n")
                            elif arg.startswith("key "):
                                raw = arg[4:].strip()
                                if raw.startswith('"'):
                                    end = raw.find('"', 1)
                                    if end == -1:
                                        end = raw.find(' ', 1)
                                    provider = raw[1:end].strip()
                                    key = raw[end+1:].strip().strip('"').strip()
                                else:
                                    key_parts = raw.split(maxsplit=1)
                                    if len(key_parts) < 2:
                                        print(f"{C_RED}Usage: /model key <provider> <key>{C_RESET}")
                                        print(f"Example: /model key openrouter sk-or-v1-xxx\n")
                                        continue
                                    provider = key_parts[0].strip()
                                    key = key_parts[1].strip()
                                self.api_keys[provider] = key
                                self.save_configs()
                                print(f"{C_GREEN}API key for '{provider}' saved.{C_RESET}\n")
                            elif arg == "key":
                                print(f"\n{C_CYAN}API Key Status:{C_RESET}")
                                for prov, key in self.api_keys.items():
                                    masked = key[:8] + "..." + key[-4:] if len(key) > 16 else key
                                    print(f"  {prov}: {masked}")
                                if not self.api_keys:
                                    print(f"  {C_GREY}No keys configured.{C_RESET}")
                                print()
                            else:
                                found = False
                                for k in DEFAULT_MODELS.keys():
                                    if arg.lower() == k.lower():
                                        self.selected_model = k
                                        found = True
                                        break
                                if not found:
                                    for m in self.custom_models:
                                        if arg.lower() == m.get("name", "").lower():
                                            self.selected_model = m.get("name")
                                            found = True
                                            break
                                if found:
                                    print(f"Switched model to: {C_CYAN}{self.selected_model}{C_RESET}\n")
                                else:
                                    print(f"{C_RED}Model '{arg}' not found. Use /model add to add it.{C_RESET}\n")

                        elif cmd == "/mode":
                            if arg.lower() in ["default", "automation", "normal"]:
                                self.chat_mode = arg.lower()
                                print(f"Chat mode set to: {C_CYAN}{self.chat_mode}{C_RESET}\n")
                            else:
                                print(f"Current mode: {C_CYAN}{self.chat_mode}{C_RESET}. Set with: /mode normal, /mode default, or /mode automation\n")
                        
                        elif cmd == "/return":
                            self.session_state["intentTracking"] = ""
                            self.save_configs()
                            print(f"{C_GREEN}Already at WORKSPACE_CORE.{C_RESET}\n")
                        
                        else:
                            print(f"{C_RED}Unknown command. Type /help for assistance.{C_RESET}\n")

                    else:
                        if prompt.startswith("!"):
                            self.handle_chat_command(prompt, chat_history)
                            continue

                        # Try local intent parser FIRST — fast, no AI needed
                        if self.chat_mode != "normal":
                            local_ack = self.local_intent_parse(prompt)
                            if local_ack:
                                print()
                                print(f"{C_CYAN}You > {C_WHITE}{prompt}{C_RESET}")
                                print(f"{C_GREEN}zournia > {C_WHITE}{local_ack}{C_RESET}\n")
                                chat_history.append(("user", prompt))
                                chat_history.append(("assistant", local_ack))
                                continue

                        # Normal chat response from workspace prompt
                        print()
                        print(f"{C_CYAN}You > {C_WHITE}{prompt}{C_RESET}")
                        print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
                        response = self.get_ai_response(prompt, chat_history)
                        retries = 0
                        safety_words = ["user safety", "safety:", "i can't", "i cannot", "i'm not able", "i'm sorry", "i apologize", "not appropriate", "can't assist"]
                        while retries < 2 and (
                            response is None
                            or (isinstance(response, str) and response.strip() == "")
                            or (isinstance(response, str) and any(w in response.lower() for w in safety_words) and not any(c in response for c in ["EXECUTE:", "SEARCH:", "TAP:", "SWIPE:", "TYPE:", "NAV:", "CLOSE:", "SCREENSHOT:", "DUMPUI:"]))
                        ):
                            retries += 1
                            response = self.get_ai_response(prompt, chat_history)
                    print(" " * 20, end="\r")

                    display_response = self.clean_response(response)
                    print(f"{C_GREEN}zournia > {C_WHITE}{display_response}{C_RESET}\n")

                    chat_history.append(("user", prompt))
                    chat_history.append(("assistant", response))

                    if self.chat_mode != "normal":
                        commands_found = self._extract_commands(response)
                        for kind, payload in commands_found:
                            if kind == "EXECUTE":
                                ack = self.execute_terminal_command(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Execution confirmation received.\n\n{ack}"))
                            elif kind == "CLOSE":
                                ack = self.terminate_process(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Close confirmation received.\n\n{ack}"))
                            elif kind == "SEARCH":
                                ack = self.search_media(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Search confirmation received.\n\n{ack}"))
                            elif kind == "TAP":
                                ack = self.phone_tap(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Tap confirmation received.\n\n{ack}"))
                            elif kind == "SWIPE":
                                ack = self.phone_swipe(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Swipe confirmation received.\n\n{ack}"))
                            elif kind == "TYPE":
                                ack = self.phone_type(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Type confirmation received.\n\n{ack}"))
                            elif kind == "NAV":
                                ack = self.phone_nav(payload)
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Nav confirmation received.\n\n{ack}"))
                            elif kind == "SCREENSHOT":
                                ack = self.phone_screenshot()
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Screenshot confirmation received.\n\n{ack}"))
                            elif kind == "DUMPUI":
                                ack = self.phone_dump_ui()
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"UI dump confirmation received.\n\n{ack}"))
                            elif kind == "VISION":
                                ack = self.phone_screenshot_vision()
                                print(f"{C_GREEN}{ack}{C_RESET}\n")
                                chat_history.append(("user", f"Vision confirmation received.\n\n{ack}"))

            except KeyboardInterrupt:
                print(f"\n{C_YELLOW}Use /exit to quit.{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}An error occurred: {e}{C_RESET}\n")

if __name__ == "__main__":
    cli = ZourniaCLI()
    cli.run()
