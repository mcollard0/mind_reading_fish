#!/usr/bin/fish

set CONFIG_FILE "$HOME/.config/fish/config.fish"
set FUNCTION_NAME "mind_reading_fish"

echo (set_color cyan)"[ Pre-flight Check ]"(set_color normal)

# 1. Dependency Verification
set -l missing 0
if not type -q ollama; and not pgrep -f "Gerbil" > /dev/null
    echo (set_color red)"Error: Neither Ollama nor Gerbil detected."(set_color normal)
    set missing 1
end

if not type -q jq
    echo (set_color red)"Error: 'jq' is required."(set_color normal)
    set missing 1
end

if test $missing -eq 1; exit 1; end

# 2. Existing Config Test (prevents double install)
if grep -q "function $FUNCTION_NAME" "$CONFIG_FILE"
    echo (set_color red)"Error: '$FUNCTION_NAME' already exists in $CONFIG_FILE."(set_color normal)
    exit 1
end

echo (set_color green)"Verification successful. Appending $FUNCTION_NAME to $CONFIG_FILE..."(set_color normal)

# 3. The Payload
set PAYLOAD "
# --- START MIND READING FISH ---
function $FUNCTION_NAME
    set -l failed_cmd (string join ' ' \$argv)
    
    # VRAM Safety: Check for Gerbil before firing up Ollama
    if ss -tuln | grep -q \":5001 \"; or pgrep -f \"Gerbil\" > /dev/null
        __fish_default_command_not_found_handler \$argv; return
    end

    echo (set_color cyan)\"Mind-reading in progress for '\$failed_cmd'...\"(set_color normal)

    # Build the JSON request
    set -l json_request '{
        \"model\": \"deepseek-coder-v2:lite\",
        \"prompt\": \"You are a shell command generator. User input: \\\"'\"\$failed_cmd\"'\\\". Output ONLY the corrected shell command(s) that accomplish their intent. Rules: 1. No explanations, no markdown, no code blocks. 2. One command per line or chain with &&. 3. If you must explain, prefix line with #. 4. If destructive (rm -rf, dd, mkfs), start with: # WARNING: DESTRUCTIVE\",
        \"stream\": false
    }'
    
    if set -q _mind_reading_fish_debug
        echo (set_color magenta)\"DEBUG: Request:\"(set_color normal)
        echo \"\$json_request\"
    end
    
    # Agentic Prompt for DeepSeek Coder V2 Lite
    set -l raw_response (curl -s http://localhost:11434/api/generate -d \"\$json_request\")
    
    if set -q _mind_reading_fish_debug
        echo (set_color magenta)\"DEBUG: Raw response:\"(set_color normal)
        echo \"\$raw_response\"
    end
    
    set -l ai_output (echo \"\$raw_response\" | jq -r '.response' | string trim)
    
    if set -q _mind_reading_fish_debug
        echo (set_color magenta)\"DEBUG: Extracted response:\"(set_color normal)
        echo \"\$ai_output\"
    end

    echo -e \"\\n\"(set_color yellow)\"--- PROPOSED EXECUTION ---\"(set_color normal)
    echo \"\$ai_output\"
    echo (set_color yellow)\"---------------------------\"(set_color normal)

    # Safety Timer logic
    set -l sleep_time 3
    if string match -qi \"*DESTRUCTIVE*\" \"\$ai_output\"
        echo (set_color -b red -w white)\" !!! DESTRUCTIVE COMMAND DETECTED !!! \"(set_color normal)
        set sleep_time 999999
    else
        echo (set_color green)\"Auto-executing in \$sleep_time seconds... (Ctrl+C to abort)\"(set_color normal)
    end

    sleep \$sleep_time
    
    # Extract only executable commands (remove markdown, comments, empty lines)
    set -l clean_cmd (echo \"\$ai_output\" | sed '/^```/d' | grep -v '^#' | grep -v '^[[:space:]]*\$' | string collect | string trim)
    
    if test -n \"\$clean_cmd\"
        eval \"\$clean_cmd\"
    else
        echo (set_color red)\"Error: No executable command extracted from AI response.\"(set_color normal)
        return 1
    end
    
    # Return 0 to indicate we handled the command
    return 0
end

# Alias the handler to the standard Fish event
alias fish_command_not_found='$FUNCTION_NAME'
# --- END MIND READING FISH ---
"

echo "$PAYLOAD" >> "$CONFIG_FILE"
echo (set_color green)"Done! Restart your shell or 'source $CONFIG_FILE' to see if I can read your mind."(set_color normal)
