#!/usr/bin/env bash
set -eo pipefail
shopt -s nullglob

# --- Path Alignment & UI Config ---
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
AI_REPO="$SCRIPT_DIR"; CACHE_DIR="$AI_REPO/.ai-cache"
TMP_DIR="$CACHE_DIR/.tmp"; LOGS_DIR="$CACHE_DIR/.logs"; MODELS_DIR="$CACHE_DIR/.models"; CDN_DIR="$CACHE_DIR/.cdnlibs"
TOP_LOG="$TMP_DIR/top.log"; PROGRESS_LOG="$TMP_DIR/progress.log"
RESET='\033[0m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'
ICON_PROMPT=$(echo -e '\U0001f916'); ICON_THINKING=$(echo -e '\U0001f9e0'); ICON_EXEC=$(echo -e '\u26a1'); ICON_FAIL=$(echo -e '\u274c')

# --- Dynamic Flags & State ---
UPDATE_MODE=false; BUILD_MODE=false; ONE_FILE=""; CODE_PROMPT=""; IMPRO_MODE=false; TALK_MODE=false
MODEL="gemma3:1b"; OLLAMA_API_URL="http://localhost:11434"
declare SYSTEM_PROMPT=""; USER_BUFFER=""

# --- UI Management ---
TERM_HEIGHT=$(tput lines); TERM_WIDTH=$(tput cols)
TOP_HEIGHT=$((TERM_HEIGHT*20/100)); MID_HEIGHT=$((TERM_HEIGHT*40/100))
VERBOSE_PANE_START=0; PROGRESS_PANE_START=$((TOP_HEIGHT + 1)); INPUT_PANE_START=$((PROGRESS_PANE_START + MID_HEIGHT + 1))
log_top() { echo "$*" > "$TOP_LOG"; }
log_mid() { echo "$(date +'%H:%M:%S') | $*" >> "$PROGRESS_LOG"; }
setup_ui() { clear; tput civis; tput cup $TOP_HEIGHT 0; printf "%${TERM_WIDTH}s"|tr " " "="; tput cup $INPUT_PANE_START 0; printf "%${TERM_WIDTH}s"|tr " " "="; }
cleanup_ui() { tput cnorm; clear; }
update_verbose_pane() { tput sc; tput cup $VERBOSE_PANE_START 0; tput ed; echo "$1" | glow -w "$TERM_WIDTH" -s dark; tput rc; }
redraw_progress_pane() { tput sc; tput cup $PROGRESS_PANE_START 0; tput ed; tail -n $MID_HEIGHT "$PROGRESS_LOG" 2>/dev/null; tput rc; }
redraw_input_pane() { tput sc; tput cup $((INPUT_PANE_START + 1)) 0; tput ed; echo -en "${BOLD}${GREEN}${ICON_PROMPT}> ${RESET}${USER_BUFFER}"; tput rc; }

# --- Core AI & System Logic ---
check_runtime_deps() { for cmd in git jq glow ollama python3 node; do if ! command -v "$cmd" &>/dev/null; then echo "FATAL: '$cmd' not found."; exit 1; fi; done; }
handle_cdn() { log_mid "Checking CDN..."; cdn_dl() { if [[ "$UPDATE_MODE" == true || ! -f "$CDN_DIR/$1.min.js" ]]; then log_mid "DL $1..."; curl -fsSL -o "$CDN_DIR/$1.min.js" "$2"; fi; }; cdn_dl "jquery3" "https://code.jquery.com/jquery-3.7.1.min.js"; cdn_dl "gsap" "https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"; cdn_dl "bootstrap5" "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"; }
handle_model_backup() { if [[ "$UPDATE_MODE" == true || ! -d "$MODELS_DIR/$MODEL" ]]; then log_mid "Backing up model..."; cp -r "$HOME/.ollama/models/blobs" "$MODELS_DIR/" 2>/dev/null || log_mid "No local model found."; fi; }
call_ollama_api_bg() {
    local messages_json="$1"; local output_file="$2"; log_mid "${ICON_THINKING} AI is thinking..."
    local payload=$(jq -n --arg model "$MODEL" --argjson messages "$messages_json" '{model: $model, messages: $messages, stream: false}')
    local response_json=$(curl -s -X POST "$OLLAMA_API_URL/api/chat" -d "$payload")
    if [[ -z "$response_json" ]] || echo "$response_json" | jq -e '.error' >/dev/null; then log_mid "${ICON_FAIL} AI API Error"; else
        echo "$response_json" | jq -r '.message.content' > "$output_file"; log_mid "AI response received."
    fi
}
execute_command_bg() {
    local cmd="$1"; local session_id="$2"; log_mid "${ICON_EXEC} Attempting: $cmd"
    local output; local exit_code; output=$(cd "$AI_REPO" && eval "$cmd" 2> "$TMP_DIR/stderr-$session_id.log" 1> "$TMP_DIR/stdout-$session_id.log"); exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        local stderr=$(<"$TMP_DIR/stderr-$session_id.log"); log_mid "${ICON_FAIL} FAILED (Exit: $exit_code): $stderr"
        local fixer_messages=$(jq -n --arg sp "Fix command. Provide ONLY corrected command." --arg up "My command \`$cmd\` failed with error: $stderr" '[{role:"system",content:$sp},{role:"user",content:$up}]')
        call_ollama_api_bg "$fixer_messages" "$TMP_DIR/verbose_output-$session_id.txt"
    else
        local stdout=$(<"$TMP_DIR/stdout-$session_id.log"); log_mid "OK."; echo "$stdout" > "$TMP_DIR/verbose_output-$session_id.txt"
    fi
}
handle_env_hooks() {
    local env_context=""; if [ -d "./node_modules/.bin" ]; then export PATH="$(pwd)/node_modules/.bin:$PATH"; env_context+="\n- NodeJS: Local './node_modules/.bin' added to PATH."; fi
    if [ -f "./venv/bin/activate" ]; then source "./venv/bin/activate"; env_context+="\n- Python: Local './venv' sourced.";
    elif [ -f "./.venv/bin/activate" ]; then source "./.venv/bin/activate"; env_context+="\n- Python: Local './.venv' sourced."; fi
    echo "$env_context"
}
eval_flags() {
    local args=($*); for arg in "${args[@]:1}"; do
        case "$arg" in build) BUILD_MODE=true ;; nbuild) BUILD_MODE=false ;; talk) TALK_MODE=true ;; strict) TALK_MODE=false ;; impro) IMPRO_MODE=true ;; noimpro) IMPRO_MODE=false ;; esac; done
    log_mid "Flags updated: build=$BUILD_MODE talk=$TALK_MODE impro=$IMPRO_MODE"
}
handle_ai_code_gen_bg() {
    local user_cmd="$1"; local session_id="$2"; local final_prompt="$user_cmd"
    [[ -n "$CODE_PROMPT" ]] && final_prompt="$CODE_PROMPT"
    [[ -n "$ONE_FILE" ]] && final_prompt="Generate complete, raw code for '$ONE_FILE' based on: $final_prompt"
    [[ "$BUILD_MODE" == true ]] && final_prompt="Generate bash commands to accomplish: $final_prompt"
    [[ "$IMPRO_MODE" == true ]] && final_prompt="Generate an improved, automated script for: $final_prompt"
    
    local messages=$(jq -n --arg sp "$SYSTEM_PROMPT" --arg up "$final_prompt" '[{role:"system",content:$sp},{role:"user",content:$up}]')
    call_ollama_api_bg "$messages" "$TMP_DIR/verbose_output-$session_id.txt"
    if [[ -n "$ONE_FILE" ]]; then log_mid "Code generation for '$ONE_FILE' is processing."; fi
}

# --- Main REPL Loop ---
main() {
    check_runtime_deps; trap cleanup_ui EXIT; mkdir -p "$TMP_DIR"; touch "$TOP_LOG" "$PROGRESS_LOG"
    while [[ $# -gt 0 ]]; do case "$1" in -u|--update) UPDATE_MODE=true;; *) ;; esac; shift; done
    local shell_rc_file=""; local shell_type=""; if [ -n "$BASH_VERSION" ]; then shell_rc_file="$HOME/.bashrc"; shell_type="Bash"; elif [ -n "$ZSH_VERSION" ]; then shell_rc_file="$HOME/.zshrc"; shell_type="Zsh"; fi
    local shell_config_content="Unknown shell."; if [[ -f "$shell_rc_file" ]]; then shell_config_content=$(cat "$shell_rc_file"); fi
    local env_hooks_context=$(handle_env_hooks)
    SYSTEM_PROMPT="You are a code-focused AI in a $shell_type REPL. Use the user's shell config and project env to provide personalized commands. Default to strict mode (code only).\n--- PROJECT ENV ---$env_hooks_context\n--- USER SHELL CONFIG ---\n$shell_config_content\n--- END CONFIG ---"
    
    local SESSION_ID=$(date +%s)-$$; PROGRESS_LOG_FILE="$LOGS_DIR/p-$SESSION_ID.log"; touch "$PROGRESS_LOG_FILE"; VERBOSE_OUTPUT_FILE="$TMP_DIR/verbose_output-$SESSION_ID.txt"
    (handle_cdn; handle_model_backup &)
    
    setup_ui; log_mid "--- AI System Initialized (PID: $$) ---"
    while true; do
        redraw_progress_pane; redraw_input_pane
        if [ -f "$VERBOSE_OUTPUT_FILE" ]; then update_verbose_pane "$(<"$VERBOSE_OUTPUT_FILE")"; rm -f "$VERBOSE_OUTPUT_FILE"; fi
        read -rsn1 -t 0.1 key
        if [[ -n "$key" ]]; then
            case "$key" in
                $'\x0a')
                    if [[ -n "$USER_BUFFER" ]]; then
                        if [[ "$USER_BUFFER" =~ ^set\  ]]; then eval_flags "$USER_BUFFER"
                        elif [[ "$USER_BUFFER" == "exit" || "$USER_BUFFER" == "quit" ]]; then break
                        elif [[ "$BUILD_MODE" == true || -n "$ONE_FILE" || -n "$CODE_PROMPT" || "$IMPRO_MODE" == true ]]; then (handle_ai_code_gen_bg "$USER_BUFFER" "$SESSION_ID" &)
                        else (execute_command_bg "$USER_BUFFER" "$SESSION_ID" &); fi
                        USER_BUFFER=""
                    fi ;;
                $'\x7f') USER_BUFFER=${USER_BUFFER%?} ;;
                *) USER_BUFFER+="$key" ;;
            esac
        fi
    done
}
main "$@"
