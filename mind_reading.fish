#!/usr/bin/fish

set CONFIG_FILE "$HOME/.config/fish/config.fish"
set FUNCTION_NAME "mind_reading_fish"
set START_MARKER "# --- START MIND READING FISH ---"
set END_MARKER "# --- END MIND READING FISH ---"

function status_component
    if grep -Fq "$START_MARKER" "$CONFIG_FILE"
        echo (set_color green)"[INSTALLED]"(set_color normal)" Mind Reading Fish is currently active in $CONFIG_FILE"
        return 0
    else
        echo (set_color yellow)"[NOT INSTALLED]"(set_color normal)" Mind Reading Fish is NOT found in $CONFIG_FILE"
        return 1
    end
end

function uninstall_component
    if not grep -Fq "$START_MARKER" "$CONFIG_FILE"
        echo (set_color yellow)"Not installed. Nothing to remove."(set_color normal)
        return 0
    end

    echo (set_color cyan)"Uninstalling Mind Reading Fish..."(set_color normal)
    # Use sed to delete the block from start marker to end marker
    # We use a temporary file to ensure safety
    sed -i "/$START_MARKER/,/$END_MARKER/d" "$CONFIG_FILE"
    
    if grep -Fq "$START_MARKER" "$CONFIG_FILE"
        echo (set_color red)"Error: Uninstall failed. Markers still found."(set_color normal)
        return 1
    else
        echo (set_color green)"Successfully uninstalled."(set_color normal)
        return 0
    end
end

function install_component
    echo (set_color cyan)"[ Pre-flight Check ]"(set_color normal)

    # 1. Dependency Verification
    set -l missing 0
    if not type -q ollama; and not pgrep -f "Gerbil" > /dev/null
        echo (set_color red)"Error: Neither Ollama nor Gerbil detected."(set_color normal)
        
        set -l install_cmd ""
        if type -q pacman
            set install_cmd "sudo pacman -S --noconfirm ollama"
        else if type -q apt
            set install_cmd "curl -fsSL https://ollama.com/install.sh | sh"
        else if type -q dnf
             set install_cmd "sudo dnf install ollama"
        else
            set install_cmd "curl -fsSL https://ollama.com/install.sh | sh"
        end

        echo (set_color yellow)"I can install it for you using:"(set_color normal)
        echo (set_color cyan)"$install_cmd"(set_color normal)
        echo (set_color cyan)"sudo systemctl enable --now ollama.service"(set_color normal)
        echo (set_color cyan)"ollama pull deepseek-coder-v2:lite"(set_color normal)

        read -P "Install? [Y/n] " -l confirm
        
        # Default to Yes if empty, or starts with y/Y/j/J
        if test -z "$confirm"; or string match -qi "y*" "$confirm"; or string match -qi "j*" "$confirm"
            echo (set_color green)"Installing..."(set_color normal)
            eval $install_cmd
            if test $status -ne 0
                echo (set_color red)"Installation failed."(set_color normal)
                set missing 1
            else
                # Enable and wait for service to be ready
                if sudo systemctl enable --now ollama.service
                    echo (set_color green)"Service enabled. Waiting for startup..."(set_color normal)
                    sleep 5
                    
                    if ollama pull deepseek-coder-v2:lite
                        echo (set_color green)"Model pulled successfully."(set_color normal)
                    else
                         echo (set_color red)"Model pull failed. Try running 'ollama pull deepseek-coder-v2:lite' manually."(set_color normal)
                         set missing 1
                    end
                else
                    echo (set_color red)"Service enablement failed."(set_color normal)
                    set missing 1
                end
            end
        else
             echo (set_color red)"Installation aborted by user."(set_color normal)
             set missing 1
        end
    end

    if not type -q jq
        echo (set_color red)"Error: 'jq' is required."(set_color normal)
        set missing 1
    end

    if test $missing -eq 1; exit 1; end

    # 2. Existing Config Test (prevents double install)
    if grep -Fq "$START_MARKER" "$CONFIG_FILE"
        echo (set_color yellow)"Already installed. Use --reinstall to force update."(set_color normal)
        return 0
    end

    echo (set_color green)"Verification successful. Appending $FUNCTION_NAME to $CONFIG_FILE..."(set_color normal)

    # 3. The Payload
    # We escape the payload carefully to ensure it's written correctly
    set PAYLOAD "
$START_MARKER
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
$END_MARKER
"

    echo "$PAYLOAD" >> "$CONFIG_FILE"
    echo (set_color green)"Done! Restart your shell or 'source $CONFIG_FILE' to see if I can read your mind."(set_color normal)
end

# Main Argument Parsing
if test (count $argv) -eq 0
    # Default behavior: Install
    install_component
else
    switch $argv[1]
        case --install
            install_component
        case --uninstall
            uninstall_component
        case --reinstall
            uninstall_component
            install_component
        case --status
            status_component
        case '*'
            echo "Usage: ./mind_reading.fish [--install | --uninstall | --reinstall | --status]"
            echo "Default is --install if no argument provided."
            exit 1
    end
end
