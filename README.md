# Mind Reading Fish 🐟🧠

Hey hey there. So I was minding my own business today, all my stories start like this and I came across the idea for a mind reading fish.

## What It Does
Automatically fixes failed shell commands using AI. When you mistype a command in Fish shell, it uses DeepSeek Coder V2 Lite (via Ollama) to suggest and auto-execute the correct command.

## Requirements

### System Dependencies
- **Fish Shell** - The shell this is designed for
- **jq** - JSON processor for parsing API responses
- **curl** - For API communication

### AI Backend (choose one)
- **Ollama** - Local LLM server running on port 11434
  - Model: `deepseek-coder-v2:lite`
- **Gerbil** - Alternative AI backend (running on port 5001)
  - If Gerbil is detected, mind reading is disabled to prevent VRAM conflicts

### Installation Requirements
- Must have write access to `~/.config/fish/config.fish`
- Function cannot already exist in config (prevents double installation)

## How It Works

### Installation Process
1. **Pre-flight checks:**
   - Verifies Ollama or Gerbil is available
   - Confirms jq is installed
   - Checks that function isn't already installed

2. **Function injection:**
   - Appends `mind_reading_fish` function to Fish config within safety markers
   - Aliases it to `fish_command_not_found` event

### Runtime Operation
1. **Failed command trigger:**
   - When you type a non-existent command, Fish calls the handler

2. **VRAM safety check:**
   - Detects if Gerbil is running (port 5001 or process check)
   - Falls back to default handler if detected

3. **AI consultation:**
   - Sends failed command to DeepSeek Coder V2 Lite
   - Prompt positions AI as "Expert CachyOS Sysadmin"
   - Requests executable commands with explanations as comments

4. **Safety mechanisms:**
   - **Normal commands:** 3-second countdown before auto-execution
   - **Destructive commands:** Infinite wait (999999 seconds) if output contains "DESTRUCTIVE"
   - Commands starting with `#` are treated as comments and not executed
   - User can abort with Ctrl+C during countdown

5. **Execution:**
   - Strips comment lines (starting with `#`)
   - Runs cleaned command via `eval`

## Usage

### Management Commands
Directly manage the installation from the script itself.

```fish
# Check status (default is Not Installed)
./mind_reading.fish --status

# Install the mind-reading function
./mind_reading.fish --install

# Uninstall/Remove the function from config
./mind_reading.fish --uninstall

# Reinstall/Update (performs uninstall -> install)
./mind_reading.fish --reinstall
```

### In Action
Once installed, simply mistype a command to trigger the mind reading:

```fish
# Try a typo
sudo pcaman -Syu

# Output:
# Mind-reading in progress for 'sudo pcaman -Syu'...
#
# --- PROPOSED EXECUTION ---
# sudo pacman -Syu
# ---------------------------
# Auto-executing in 3 seconds... (Ctrl+C to abort)
```

## Safety Features
- **Marked Injection** - Uses start/end markers in `config.fish` for safe removal.
- **VRAM conflict avoidance** - Disables when Gerbil is running.
- **Destructive command detection** - Infinite delay for dangerous operations.
- **Manual abort** - Ctrl+C cancels execution.
- **Comment filtering** - Only executes actual commands, not explanations.
- **Prompt engineering** - AI instructed to mark destructive commands explicitly.

## Technical Details

### AI Prompt Structure
Role: Expert CachyOS Sysadmin

Rules:
1. Executable commands only
2. Chain commands with `&&` (one per line)
3. Prefix explanations with `#`
4. Mark destructive commands with `# WARNING: DESTRUCTIVE`

### File Modifications
- Appends to: `~/.config/fish/config.fish`
- Function name: `mind_reading_fish`
- Aliases: `fish_command_not_found`
