#!/usr/bin/env bash

# --- AI v37 - Definitive System Provisioner ---
# Version: 1.0
# This script installs the complete AI v37 system. It automatically provisions
# the required environment (git, jq, glow, ollama) and aligns all paths
# relative to the user's home directory for robust local file access on Termux.

set -e

# --- UI and Utility Functions for the Installer ---
RESET='\033[0m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'
ICON_SUCCESS=$(echo -e '\u2705'); ICON_INFO=$(echo -e '\u2139\ufe0f'); ICON_WARN=$(echo -e '\u26a0\ufe0f')

info() { echo -e "${BOLD}${BLUE}${ICON_INFO}  $1${RESET}"; }
success() { echo -e "${BOLD}${GREEN}${ICON_SUCCESS} Success: $1${RESET}"; }
warn() { echo -e "${BOLD}${YELLOW}${ICON_WARN}  Warning: $1${RESET}"; }
error() { echo -e "\n${BOLD}${RED}\u274c Error:${RESET} $1" >&2; exit 1; }
header() {
    local title=" $1 "; local len=${#title}; local line; line=$(printf '%*s' "$len" | tr ' ' '=')
    echo -e "\n${BOLD}${YELLOW}===${line}===${RESET}\n${BOLD}${YELLOW}===${title}===${RESET}\n${BOLD}${YELLOW}===${line}===${RESET}\n"
}

# --- V37: Environment Provisioning Logic ---
check_and_install_deps() {
    header "Provisioning Environment"
    local PKG_MANAGER=""; local INSTALL_CMD=""; local MISSING_PKGS=()

    if command -v pkg &>/dev/null; then PKG_MANAGER="pkg"; INSTALL_CMD="pkg install -y";
    elif command -v apt-get &>/dev/null; then PKG_MANAGER="apt-get"; if ! command -v sudo &>/dev/null; then error "sudo is required for apt-get."; fi; INSTALL_CMD="sudo apt-get install -y"; info "Updating package lists..."; sudo apt-get update >/dev/null 2>&1;
    else warn "Could not detect 'pkg' or 'apt-get'. Please install dependencies manually: git, jq, glow, ollama"; return; fi
    
    info "Detected package manager: $PKG_MANAGER"

    for pkg in git jq glow; do
        if ! command -v "$pkg" &>/dev/null; then info "'$pkg' is not installed."; MISSING_PKGS+=("$pkg");
        else success "'$pkg' is already installed."; fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        read -p "Missing packages: ${MISSING_PKGS[*]}. Install them? [Y/n] " confirm
        if [[ ! "$confirm" =~ ^[nN]$ ]]; then info "Installing packages..."; $INSTALL_CMD "${MISSING_PKGS[@]}"; success "Packages installed.";
        else error "User aborted dependency installation."; fi
    fi

    if ! command -v ollama &>/dev/null; then
        warn "'ollama' not found."; read -p "Install Ollama via its official script? [Y/n] " confirm
        if [[ ! "$confirm" =~ ^[nN]$ ]]; then info "Installing Ollama..."; curl -fsSL https://ollama.com/install.sh | sh; success "Ollama installed.";
        else error "User aborted Ollama installation."; fi
    else success "'ollama' is installed."; fi
}

# --- Installation Logic ---
install() {
    check_and_install_deps # Run the provisioning step first
    header "AI v37 Context-Aware System Installer"
    
    local INSTALL_DIR="$HOME/.local/bin"; local AI_COMMAND_FILE="$INSTALL_DIR/ai"; local AI_REPO_PATH="$HOME/ai-auto"
    local SHELL_PROFILE="$HOME/.bashrc"; # Default, script will auto-detect zsh
    
    info "Setting up AI repository at $AI_REPO_PATH..."
    if [ ! -d "$AI_REPO_PATH/.git" ]; then info "Cloning repository..."; git clone https://github.com/Loopshape/ai-auto.git "$AI_REPO_PATH"; else
        info "Repository exists. Fetching updates..."; cd "$AI_REPO_PATH"; git fetch --all; git reset --hard @{u} >/dev/null 2>&1 || git reset --hard origin/main >/dev/null 2>&1; cd - >/dev/null; fi
    success "Repository is ready."

    info "Ensuring project structure..."; mkdir -p "$AI_REPO_PATH/tmp/originals" "$AI_REPO_PATH/models" "$AI_REPO_PATH/cdnlibs" "$AI_REPO_PATH/logs"
    info "Configuring .gitignore..."; cat <<EOF > "$AI_REPO_PATH/.gitignore"
/models/ /cdnlibs/ /tmp/ /logs/ *.log *.bak *.swp
EOF
    info "Creating main 'ai' command at $AI_COMMAND_FILE..."
    cat <<'EOF' > "$AI_COMMAND_FILE"
#!/usr/bin/env bash
#
# AI v37 - The Self-Sufficient Command
# Validates its own dependencies and uses paths relative to the user's home directory.
#

set -eo pipefail
shopt -s nullglob

# --- V37: Path Alignment relative to User Root Folder ---
AI_REPO="$HOME/ai-auto"
TMP_DIR="$AI_REPO/tmp"; LOGS_DIR="$AI_REPO/logs"; MODELS_DIR="$AI_REPO/models"; CDN_DIR="$AI_REPO/cdnlibs"

# --- Rich UI Configuration ---
RESET='\033[0m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'
ICON_PROMPT=$(echo -e '\U0001f916'); ICON_THINKING=$(echo -e '\U0001f9e0'); ICON_EXEC=$(echo -e '\u26a1'); ICON_FAIL=$(echo -e '\u274c')

# --- Dynamic Flags (Defaults) ---
UPDATE_MODE=false; BUILD_MODE=false; ONE_FILE=""; CODE_PROMPT=""; IMPRO_MODE=false; TALK_MODE=false; PROMPT_CONFIRM=false
MODEL="gemma3:1b"; OLLAMA_API_URL="http://localhost:11434"
declare SYSTEM_PROMPT=""

# --- UI Management ---
TERM_HEIGHT=$(tput lines); TERM_WIDTH=$(tput cols)
TOP_HEIGHT=$((TERM_HEIGHT*20/100)); MID_HEIGHT=$((TERM_HEIGHT*40/100))
TOP_LOG="$TMP_DIR/top.log"; PROGRESS_LOG="$TMP_DIR/progress.log"

log_top() { echo "$*" > "$TOP_LOG"; }
log_mid() { echo "$(date +'%H:%M:%S') | $*" >> "$PROGRESS_LOG"; }
refresh_view() { tput sc; tput cup 0 0; tput ed; tput setaf 6; tail -n "$TOP_HEIGHT" "$TOP_LOG" 2>/dev/null | glow -w "$TERM_WIDTH" -s dark; tput sgr0; tput cup $((TOP_HEIGHT + 1)) 0; tput ed; tail -n "$MID_HEIGHT" "$PROGRESS_LOG" 2>/dev/null; tput cup $TOP_HEIGHT 0; printf "%${TERM_WIDTH}s" | tr " " "="; tput cup $((TOP_HEIGHT + MID_HEIGHT + 1)) 0; printf "%${TERM_WIDTH}s" | tr " " "="; tput rc; }
cleanup_ui() { tput cnorm; clear; }

# --- System & AI Logic ---
# V37: Runtime dependency validation
check_runtime_deps() { for cmd in git jq glow ollama; do if ! command -v "$cmd" &>/dev/null; then echo -e "\n\033[1;31mFATAL ERROR: Command '$cmd' not found. Please run the installer again or install it manually.\033[0m"; exit 1; fi; done; }
handle_cdn() { log_mid "Checking CDN libraries..."; cdn_dl() { if [[ "$UPDATE_MODE" == true || ! -f "$CDN_DIR/$1.min.js" ]]; then log_mid "Downloading $1..."; curl -fsSL -o "$CDN_DIR/$1.min.js" "$2"; log_mid "$1 updated."; fi; }; cdn_dl "jquery3" "https://code.jquery.com/jquery-3.7.1.min.js"; cdn_dl "gsap" "https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"; cdn_dl "bootstrap5" "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"; }
handle_model_backup() { log_mid "Checking AI model backup..."; if [[ "$UPDATE_MODE" == true || ! -d "$MODELS_DIR/$MODEL" ]]; then log_mid "Backing up model: $MODEL..."; cp -r "$HOME/.ollama/models/blobs" "$MODELS_DIR/" 2>/dev/null || log_mid "Local model not found, skipping."; fi; }
call_ollama_api() {
    local messages_json="$1"; local spin_message="${2:-AI is thinking...}"; log_mid "${ICON_THINKING} $spin_message"
    local payload=$(jq -n --arg model "$MODEL" --argjson messages "$messages_json" '{model: $model, messages: $messages, stream: false}')
    local response_json=$(curl -s -X POST "$OLLAMA_API_URL/api/chat" -d "$payload")
    if [[ -z "$response_json" ]] || echo "$response_json" | jq -e '.error' >/dev/null; then log_mid "${ICON_FAIL} AI API Error: $(echo "$response_json" | jq -r '.error // "No response")'"; return 1; fi
    echo "$response_json" | jq -c '.message'
}

# --- REPL Command Handlers ---
eval_flags() { local args=($*); for arg in "${args[@]:1}"; do case "$arg" in build) BUILD_MODE=true ;; nbuild) BUILD_MODE=false ;; talk) TALK_MODE=true ;; strict) TALK_MODE=false ;; impro) IMPRO_MODE=true ;; noimpro) IMPRO_MODE=false ;; esac; done; log_mid "Flags updated: build=$BUILD_MODE talk=$TALK_MODE impro=$IMPRO_MODE"; }
handle_ai_code_gen() {
    local user_cmd="$1"; local final_prompt="$user_cmd"; if [[ -n "$CODE_PROMPT" ]]; then final_prompt="$CODE_PROMPT"; fi; if [[ -n "$ONE_FILE" ]]; then final_prompt="Generate complete, raw code for '$ONE_FILE' based on: $final_prompt"; fi
    if [[ "$BUILD_MODE" == true ]]; then final_prompt="Generate bash commands to accomplish: $final_prompt"; fi; if [[ "$IMPRO_MODE" == true ]]; then final_prompt="Generate an improved, automated script for: $final_prompt"; fi
    local mode="strict"; if [[ "$TALK_MODE" == true ]]; then mode="chat"; fi; local messages=$(jq -n --arg sp "$SYSTEM_PROMPT" --arg up "$final_prompt" '[{role:"system",content:$sp},{role:"user",content:$up}]')
    local ai_response_obj; ai_response_obj=$(call_ollama_api "$messages"); local ai_content; ai_content=$(echo "$ai_response_obj" | jq -r '.content'); log_top "$ai_content"; log_mid "AI code generation complete."
    if [[ -n "$ONE_FILE" ]]; then echo "$ai_content" > "$AI_REPO/$ONE_FILE"; log_mid "Output saved to $AI_REPO/$ONE_FILE"; fi
}

# --- Main REPL Loop ---
ai_repl() {
    local shell_rc_file=""; local shell_type=""; if [ -n "$BASH_VERSION" ]; then shell_rc_file="$HOME/.bashrc"; shell_type="Bash"; elif [ -n "$ZSH_VERSION" ]; then shell_rc_file="$HOME/.zshrc"; shell_type="Zsh"; fi
    local shell_config_content="User is running an unknown shell."; if [[ -f "$shell_rc_file" ]]; then shell_config_content=$(cat "$shell_rc_file"); log_mid "Reading $shell_type context from $shell_rc_file..."; fi
    SYSTEM_PROMPT="You are Gemini 2.5, a code-focused AI. Your environment is $shell_type. You have been given the user's shell configuration to understand their aliases, functions, and environment variables. Use this deep context to provide highly accurate and personalized commands. Default to strict mode (code only). Switch to chat mode (with explanations) when asked.\n--- USER SHELL CONFIGURATION ---\n$shell_config_content\n--- END CONFIGURATION ---"
    
    log_mid "AI REPL v37 Initialized. Awaiting user input..."; local chat_history=$(jq -n --arg content "$SYSTEM_PROMPT" '[{role:"system",content:$content}]')
    
    while true; do
        refresh_view; local user_input; read -e -p "$(echo -e "${BOLD}${GREEN}${ICON_PROMPT}> ${RESET}")" user_input
        case "$user_input" in exit|quit) break ;; " ") log_mid "AI tilt!"; continue ;; set\ *) eval_flags "$user_input"; continue ;; esac
        if [[ "$BUILD_MODE" == true || -n "$ONE_FILE" || -n "$CODE_PROMPT" || "$IMPRO_MODE" == true ]]; then handle_ai_code_gen "$user_input"; continue; fi
        
        local output; local exit_code; output=$(eval "$user_input" 2>&1); exit_code=$?; log_top "$output"
        if [[ $exit_code -ne 0 ]]; then
            log_mid "${ICON_FAIL} Shell command failed. Consulting AI for fix..."; local fixer_messages=$(jq -n --arg sp "Fix shell command. Provide ONLY the corrected command." --arg up "My command \`$user_input\` failed with error: $output" '[{role:"system",content:$sp},{role:"user",content:$up}]')
            local ai_fix_obj; ai_fix_obj=$(call_ollama_api "$fixer_messages" "Generating fix..."); log_top "AI Suggestion:\n$(echo "$ai_fix_obj" | jq -r '.content')"
        else
            log_mid "Shell command successful."; if [[ "$TALK_MODE" == true ]]; then
                chat_history=$(echo "$chat_history" | jq --arg content "$user_input" '. + [{role:"user", content:$content}]'); local ai_response_obj; ai_response_obj=$(call_ollama_api "$chat_history" "Thinking...")
                chat_history=$(echo "$chat_history" | jq --argjson msg "$ai_response_obj" '. + [$msg]'); log_top "$(echo "$ai_response_obj" | jq -r '.content')"
            fi
        fi
    done
}

# --- Main Dispatcher ---
main() {
    check_runtime_deps # Validate dependencies every time the script runs
    trap cleanup_ui EXIT
    touch "$TOP_LOG" "$PROGRESS_LOG" # Ensure log files exist
    while [[ $# -gt 0 ]]; do
        case "$1" in -u|--update) UPDATE_MODE=true;; -b|--build) BUILD_MODE=true;; -o|--one) ONE_FILE="$2"; shift;; -c|--code) CODE_PROMPT="$2"; shift;; -i|--impro) IMPRO_MODE=true;; -t|--talk) TALK_MODE=true;; -p|--prompt) PROMPT_CONFIRM=true;; esac; shift
    done
    clear; log_mid "--- AI v37 System Start ---"; handle_cdn; handle_model_backup; ai_repl
}
main "$@"
EOF
    chmod +x "$AI_COMMAND_FILE"; success "Main 'ai' command created."

    # --- Step 5: Configure shell alias ---
    info "Configuring 'ai' alias in your shell profile..."
    local shell_profile="$HOME/.bashrc"; if [ -n "$ZSH_VERSION" ]; then shell_profile="$HOME/.zshrc"; fi; touch "$shell_profile"
    sed -i.bak '/# --- Load AI v[0-9]\+.* ---/,/fi/d' "$shell_profile"
    cat <<EOF >> "$shell_profile"

# --- Load AI v37 Alias ---
if [ -f "$AI_COMMAND_FILE" ]; then
    alias ai='$AI_COMMAND_FILE'
fi
EOF
    success "Shell alias configured in $shell_profile."

    # --- Final Instructions ---
    echo ""; success "Installation complete! The 'ai' command is now your personalized portal.";
    info "To activate the new system, please restart your shell or run:"; echo -e "  ${BOLD}${GREEN}source $shell_profile${RESET}"
}

# --- Uninstaller ---
uninstall() {
    header "AI v37 System Uninstaller"; local AI_COMMAND_FILE="$HOME/.local/bin/ai"; local shell_profile="$HOME/.bashrc"; if [ -n "$ZSH_VERSION" ]; then shell_profile="$HOME/.zshrc"; fi
    warn "This will remove the 'ai' command and its alias. It will NOT delete '~/ai-auto'."
    read -p "Proceed? [y/N]: " -r confirm; if [[ ! "$confirm" =~ ^[Yy]$ ]]; then info "Cancelled."; exit 0; fi
    info "Removing 'ai' command..."; rm -f "$AI_COMMAND_FILE";
    info "Cleaning $shell_profile..."; sed -i.bak '/# --- Load AI v37 Alias ---/,/fi/d' "$shell_profile";
    success "Uninstallation complete. Please restart your shell."
}

# --- Installer Entrypoint ---
if [[ "$1" == "--uninstall" ]]; then uninstall; else install; fi