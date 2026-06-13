#!/usr/bin/env python3
import os
import sys
import json
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
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
███████╗ ██████╗ ██╗   ██╗██████╗ ███╗   ██╗██╗ █████╗ 
╚══███╔╝██╔═══██╗██║   ██║██╔══██╗████╗  ██║██║██╔══██╗
  ███╔╝ ██║   ██║██║   ██║██████╔╝██╔██╗ ██║██║███████║
 ███╔╝  ██║   ██║██║   ██║██╔══██╗██║╚██╗██║██║██╔══██║
███████╗╚██████╔╝╚██████╔╝██║  ██║██║ ╚████║██║██║  ██║
╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
                      {C_GREY}// TERMUX_CORE{C_RESET}
"""

DEFAULT_MODELS = {
    "Gemini": "google/gemini-2.5-flash",
    "Qwen": "qwen/qwen-2.5-coder-32b-instruct"
}

class ZourniaCLI:
    def __init__(self):
        self.api_keys = {}
        self.custom_models = []
        self.session_state = {"lastAction": "", "targetPid": None, "intentTracking": ""}
        self.chat_mode = "default"  # default or automation
        self.selected_model = "Gemini"
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
                    self.session_state = json.load(f)
            except Exception as e:
                pass

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
            with open(session_state_path, "w") as f:
                json.dump(self.session_state, f, indent=2)
        except Exception as e:
            pass

    def get_api_key(self):
        return self.api_keys.get("OpenRouter", "")

    def validate_command(self, command: str) -> bool:
        cmd_lower = command.lower().strip()
        destructive_keywords = [
            'del ', 'del/', 'del.exe',
            'rm ', 'rmdir', 'rm.exe',
            'remove-item', 'ri ',
            'erase ', 'erase/',
            'rd ', 'rd/',
            'format',
            'sfc ', 'sfc/',
            'dism',
            'diskpart',
            'reg delete',
            'taskkill /f /im svchost.exe',
            'taskkill /f /pid 4',
        ]
        critical_system_paths = [
            'system32',
            'windows',
            'system volume information',
            'boot',
            'recovery',
            'program files',
            'programfiles',
            'users',
            'c:\\users',
            'c:/users',
            'c:\\windows',
            'c:/windows',
        ]
        # Guardrail 1
        for kw in destructive_keywords:
            if kw in cmd_lower:
                for sys_path in critical_system_paths:
                    if sys_path in cmd_lower:
                        return False
        # Guardrail 2
        if 'format ' in cmd_lower or 'format/' in cmd_lower:
            return False
        # Guardrail 3
        if 'rm -rf /' in cmd_lower or 'rm -rf c:' in cmd_lower:
            return False
        return True

    def get_model_identifier(self):
        if self.selected_model in DEFAULT_MODELS:
            return DEFAULT_MODELS[self.selected_model]
        
        # Check custom models
        for m in self.custom_models:
            if m.get("name") == self.selected_model:
                return m.get("identifier", "google/gemini-2.5-flash")
                
        return "google/gemini-2.5-flash"

    def get_system_info(self):
        home_dir = os.environ.get('HOME', '/data/data/com.termux/files/home')
        user = os.environ.get('USER', 'u0_a0')
        return (
            "Active Environment Information:\n"
            f"- OS: Android / Termux\n"
            f"- USER: {user}\n"
            f"- HOME: {home_dir}\n\n"
            "File Access & Exploration Commands:\n"
            "- To search for files or folders, use: find <path> -name \"*pattern*\"\n"
            "- To read a file, use: cat \"<file_path>\"\n"
            "- To list directory contents, use: ls \"<path>\"\n"
            "- To launch or run terminal commands, output its path or name directly (e.g. EXECUTE: python script.py or EXECUTE: ls -la). Run commands directly so the Termux system can execute them.\n\n"
            "Termux/Android Commands:\n"
            "- To open a URL or website in the user's browser, use: EXECUTE: termux-open \"<url>\" or termux-open-url \"<url>\" (e.g. EXECUTE: termux-open \"https://google.com\").\n"
        )

    def execute_terminal_command(self, command: str) -> str:
        if not self.validate_command(command):
            return "EXECUTION BLOCKED: Command execution is prohibited by Zournia Security Jail."

        print(f"{C_YELLOW}Executing: {command}{C_RESET}")
        try:
            # Try parsing command name
            tokens = command.split()
            app_name = tokens[0].split('/')[-1] if tokens else "command"

            # Start process
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

            # Wait briefly to capture fast output
            time.sleep(0.5)
            
            # Check if it finished or is running
            status = process.poll()
            if status is None:
                return f"EXECUTION ACK: Command \"{command}\" triggered successfully. Process: \"{app_name}\" (PID: {process.pid}) is running in background."
            else:
                stdout, stderr = process.communicate()
                out_text = stdout.decode('utf-8', errors='replace')
                err_text = stderr.decode('utf-8', errors='replace')
                
                output = ""
                if out_text.strip():
                    output += f"\n\nOutput:\n{out_text}"
                if err_text.strip():
                    output += f"\n\nError:\n{err_text}"
                
                return f"EXECUTION ACK: Command \"{command}\" executed successfully with status {status}.{output}"
        except Exception as e:
            return f"Failed to execute command: {e}"

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
        api_key = self.get_api_key()
        if not api_key:
            return "Error: API key is not configured. Use /help to see how to set it."

        model_name = self.get_model_identifier()
        
        session_state_str = (
            f"Active Session State:\n"
            f"- LAST_ACTION: {self.session_state.get('lastAction') or 'None'}\n"
            f"- TARGET_PID: {self.session_state.get('targetPid') or 'None'}\n"
            f"- INTENT_TRACKING: {self.session_state.get('intentTracking') or 'None'}\n"
        )
        system_info_str = self.get_system_info()

        platform_name = "Android/Termux environment"
        shell_name = "Android shell"
        yt_example = "termux-open https://youtube.com"
        notepad_example = "ls -la"
        close_example = "'CLOSE: <process_name>' or 'EXECUTE: kill -9 <PID>'"
        taskkill_example = "kill -9 <TARGET_PID>"

        if self.chat_mode == "automation":
            system_prompt = (
                f"You are running in AUTOMATION mode on the user's {platform_name}. "
                f"Chat in a casual, direct, developer-to-developer tone. Avoid robotic pleasantries or AI template-speak. "
                f"If the user asks you to perform a task (e.g. open a website, run a CLI command), you must output a command line starting with 'EXECUTE: ' followed by the {shell_name} command. Example: reply with exactly 'EXECUTE: {yt_example}'. To run command, reply with 'EXECUTE: {notepad_example}'. "
                f"If the user asks to close an application or undo a launch, you must reply with exactly {close_example}. "
                f"Additionally, if the user refers to 'it' or 'that process' (e.g. 'close it', 'kill it'), you must resolve 'it' to the active TARGET_PID or process name from the Session State and output the command using that PID or app name (e.g. 'CLOSE: <app_name>' or 'EXECUTE: {taskkill_example}'). "
                f"CRITICAL: If the user asks you to perform an action, you MUST immediately output the EXECUTE statement. Do NOT write conversational text explaining how the user can do it themselves. Do it for them instantly using EXECUTE. "
                f"Do not output markdown code blocks, brackets, quotes or any extra conversation. Just reply with the single EXECUTE or CLOSE line. "
                f"You must also include a line starting with 'INTENT: <brief semantic summary>' to update the active tracking intent if the user's current goal or topic has shifted. Example response:\n"
                f"EXECUTE: {notepad_example}\n"
                f"INTENT: User is executing a shell command\n\n"
                f"{session_state_str}\n\n{system_info_str}"
            )
        elif self.chat_mode == "normal":
            system_prompt = (
                f"You are a casual, conversational AI assistant running on the user's {platform_name}. "
                f"This is NORMAL mode — pure chat only. No automation, no command execution, no system calls. "
                f"Act as human as possible: use a warm, casual, developer-to-developer conversational tone. "
                f"Do NOT use assistant cliches like 'As an AI...', 'Certainly! I can help you with that'. Speak naturally, directly, and informally. "
                f"You can discuss anything: coding, life, ideas, jokes, philosophy, whatever the user wants. "
                f"NEVER output 'EXECUTE:', 'CLOSE:', or 'INTENT:' lines. Just talk normally.\n\n"
                f"{session_state_str}\n\n{system_info_str}"
            )
        else:
            system_prompt = (
                f"You are a helpful coding and system assistant running on the user's {platform_name}. "
                f"Act as human as possible: use a warm, casual, developer-to-developer conversational tone. Do NOT use assistant cliches like 'As an AI...', 'Certainly! I can help you with that'. Speak naturally, directly, and informally. "
                f"You can chat normally, write code, explain concepts, and also execute system automation commands if the user requests them. "
                f"If the user asks you to perform a task (e.g. open a website, run a CLI command), you must output a line starting with 'EXECUTE: ' followed by the {shell_name} command (e.g. 'EXECUTE: {yt_example}' or 'EXECUTE: {notepad_example}'). "
                f"If the user asks to close an application or undo a launch, you must reply with exactly {close_example}. "
                f"Additionally, if the user refers to 'it' or 'that process', you must resolve 'it' to the active TARGET_PID or process name from the Session State and output the command using that PID or app name (e.g. 'CLOSE: <app_name>' or 'EXECUTE: {taskkill_example}'). "
                f"CRITICAL: If the user asks you to perform an action, you MUST immediately output the EXECUTE statement to perform it. Do NOT write explanations. Perform the action for them instantly using EXECUTE. "
                f"For general questions or conversational replies, respond normally. "
                f"You must also include a line starting with 'INTENT: <brief semantic summary>' to update the active tracking intent if the user's current goal or topic has shifted.\n\n"
                f"{session_state_str}\n\n{system_info_str}"
            )

        # Assemble messages payload
        messages_payload = [{"role": "system", "content": system_prompt}]
        for role, text in chat_history[-10:]:
            messages_payload.append({"role": role, "content": text})
        
        messages_payload.append({"role": "user", "content": prompt})

        # POST request using urllib.request
        url = "https://openrouter.ai/api/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://zournia.internal",
            "X-Title": "Zournia OS",
        }
        body = json.dumps({
            "model": model_name,
            "messages": messages_payload,
            "max_tokens": 1024
        }).encode('utf-8')

        req = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req) as res:
                response_data = json.loads(res.read().decode('utf-8'))
                choices = response_data.get("choices", [])
                if choices:
                    return choices[0]["message"]["content"]
                return "Error: Empty response choices returned from model."
        except urllib.error.HTTPError as e:
            return f"Error: Server returned status code {e.code} - {e.read().decode('utf-8', errors='replace')}"
        except Exception as e:
            return f"Network Error: {e}"

    def run(self):
        print(BANNER)
        
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

        while True:
            try:
                prompt = input(f"{C_GREEN}ZOURNIA // WORKSPACE_CORE > {C_RESET}").strip()
                if not prompt:
                    continue

                if prompt.startswith("/"):
                    # Process slash commands
                    cmd_parts = prompt.split(maxsplit=1)
                    cmd = cmd_parts[0].lower()
                    arg = cmd_parts[1].strip() if len(cmd_parts) > 1 else ""

                    if cmd in ["/exit", "/quit"]:
                        print(f"{C_YELLOW}Exiting Zournia CLI. Goodbye.{C_RESET}")
                        break
                    
                    elif cmd == "/help":
                        print(f"\n{C_WHITE}Zournia CLI Commands:{C_RESET}")
                        print(f"  {C_GREEN}/model [name]{C_RESET}     Switch active AI model (e.g. Gemini, Qwen, or custom name).")
                        print(f"  {C_GREEN}/mode [normal|default|automation]{C_RESET} Switch chat mode.")
                        print(f"  {C_GREEN}/telemetry{C_RESET}        Print active environment diagnostics panel.")
                        print(f"  {C_GREEN}/help{C_RESET}             Show this help menu.")
                        print(f"  {C_GREEN}/exit{C_RESET}             Close the client.\n")
                    
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
                            print(f"\nAvailable Models:")
                            print(f"  - Gemini (google/gemini-2.5-flash) [active]" if self.selected_model == "Gemini" else "  - Gemini (google/gemini-2.5-flash)")
                            print(f"  - Qwen (qwen/qwen-2.5-coder-32b-instruct) [active]" if self.selected_model == "Qwen" else "  - Qwen (qwen/qwen-2.5-coder-32b-instruct)")
                            for m in self.custom_models:
                                name = m.get("name")
                                id_ = m.get("identifier")
                                print(f"  - {name} ({id_}) [active]" if self.selected_model == name else f"  - {name} ({id_})")
                            print()
                        else:
                            # Try to match
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
                                print(f"{C_RED}Error: Model '{arg}' not found.{C_RESET}\n")

                    elif cmd == "/mode":
                        if arg.lower() in ["default", "automation", "normal"]:
                            self.chat_mode = arg.lower()
                            print(f"Chat mode set to: {C_CYAN}{self.chat_mode}{C_RESET}\n")
                        else:
                            print(f"Current mode: {C_CYAN}{self.chat_mode}{C_RESET}. Set with: /mode normal, /mode default, or /mode automation\n")
                    
                    else:
                        print(f"{C_RED}Unknown command. Type /help for assistance.{C_RESET}\n")

                else:
                    # Normal chat response
                    print()
                    print(f"{C_CYAN}You > {C_WHITE}{prompt}{C_RESET}")
                    print(f"{C_GREY}Thinking...{C_RESET}", end="\r")
                    response = self.get_ai_response(prompt, chat_history)
                    # Clear "Thinking..."
                    print(" " * 20, end="\r")
                    
                    # Print response
                    print(f"{C_GREEN}Zournia > {C_WHITE}{response}{C_RESET}\n")
                    
                    chat_history.append(("user", prompt))
                    chat_history.append(("assistant", response))

                    # Parse response lines for intent tracking or execution triggers
                    lines = response.split("\n")
                    for line in lines:
                        line = line.strip()
                        if line.startswith("INTENT:"):
                            self.session_state["intentTracking"] = line.replace("INTENT:", "").strip()
                            self.save_configs()
                        
                        if self.chat_mode == "normal":
                            continue

                        if line.startswith("EXECUTE:"):
                            cmd_to_run = line.replace("EXECUTE:", "").strip()
                            ack = self.execute_terminal_command(cmd_to_run)
                            print(f"{C_GREEN}{ack}{C_RESET}\n")
                            chat_history.append(("user", f"Execution confirmation received.\n\n{ack}"))

                        elif line.startswith("CLOSE:"):
                            target_to_close = line.replace("CLOSE:", "").strip()
                            ack = self.terminate_process(target_to_close)
                            print(f"{C_GREEN}{ack}{C_RESET}\n")
                            chat_history.append(("user", f"Close confirmation received.\n\n{ack}"))

            except KeyboardInterrupt:
                print(f"\n{C_YELLOW}Use /exit to quit.{C_RESET}\n")
            except Exception as e:
                print(f"{C_RED}An error occurred: {e}{C_RESET}\n")

if __name__ == "__main__":
    cli = ZourniaCLI()
    cli.run()
