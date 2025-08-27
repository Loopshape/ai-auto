#!/usr/bin/env bash

# --- AI v58 - Definitive Repo-Root Configurator ---
# Version: 1.0
# This script configures a cloned 'ai-auto' repository. It sanitizes the
# environment, creates the cache structure, makes the 'ai' script executable,
# and hooks it into the user's shell profile.

set -e

# --- UI and Utility Functions for the Installer ---
RESET='\033[0m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'
ICON_SUCCESS=$(echo -e '\u2705'); ICON_INFO=$(echo -e '\u2139\ufe0f'); ICON_WARN=$(echo -e '\u26a0\ufe0f'); ICON_CLEAN=$(echo -e '\U0001f9f9')

info() { echo -e "${BOLD}${BLUE}${ICON_INFO}  $1${RESET}"; }
success() { echo -e "${BOLD}${GREEN}${ICON_SUCCESS} Success: $1${RESET}"; }
warn() { echo -e "${BOLD}${YELLOW}${ICON_WARN}  Warning: $1${RESET}"; }
error() { echo -e "\n${BOLD}${RED}\u274c Error:${RESET} $1" >&2; exit 1; }
header() {
    local title=" $1 "; local len=${#title}; local line; line=$(printf '%*s' "$len" | tr ' ' '=')
    echo -e "\n${BOLD}${YELLOW}===${line}===${RESET}\n${BOLD}${YELLOW}===${title}===${RESET}\n${BOLD}${YELLOW}===${line}===${RESET}\n"
}

# --- Sanitization and Provisioning ---
sanitize_environment() {
    header "Sanitizing Environment of Old Installations"
    local was_cleaned=false; local old_command="$HOME/.local/bin/ai"; local old_core_dir="$HOME/.ai_core"; local old_repo="$HOME/ai-auto"; local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc")
    if [ -f "$old_command" ]; then info "Removing old global command: $old_command"; rm -f "$old_command"; was_cleaned=true; fi
    if [ -d "$old_core_dir" ]; then info "Removing old core dir: $old_core_dir"; rm -rf "$old_core_dir"; was_cleaned=true; fi
    if [[ -d "$old_repo" && "$(pwd)" != "$old_repo" ]]; then info "Removing old fixed-path repo: $old_repo"; rm -rf "$old_repo"; was_cleaned=true; fi
    for profile in "${shell_profiles[@]}"; do
        if [ -f "$profile" ] && grep -qE "(# --- Load AI v[0-9]+.* ---|alias ai=|ai\(\))" "$profile"; then
            info "Cleaning old configurations from $profile..."; cp "$profile" "$profile.bak.$(date +%s)";
            sed -i.bak -e '/# --- Load AI v[0-9]\+.* ---/,/fi/d' "$profile"; info "A backup was created at $profile.bak"; was_cleaned=true
        fi; done
    if [[ "$was_cleaned" == true ]]; then success "Environment sanitization complete."; else info "No abandoned fixed-path installations found."; fi
}
check_and_install_deps() {
    # This is a placeholder for the robust dependency checker.
    :
}

# --- Main Configuration Logic ---
configure_repo() {
    sanitize_environment; check_and_install_deps; header "AI v58 System Configurator"
    
    local AI_REPO_PATH="."; local AI_COMMAND_FILE="$AI_REPO_PATH/ai"; local CACHE_DIR="$AI_REPO_PATH/.ai-cache"
    
    info "Configuring project structure in current directory..."
    mkdir -p "$CACHE_DIR/.tmp/originals" "$CACHE_DIR/.models" "$CACHE_DIR/.cdnlibs" "$CACHE_DIR/.logs"
    success "Hidden cache structure is ready at $CACHE_DIR"

    info "Configuring .gitignore..."; 
    cat <<'EOF' > "$AI_REPO_PATH/.gitignore"
/.ai-cache/
/configure.sh
*.swp
*.bak
*~
.DS_Store
EOF
    success ".gitignore is configured."
    
    info "Making 'ai' script executable..."
    if [ ! -f "$AI_COMMAND_FILE" ]; then
        error "'ai' script not found in repository root. Please ensure it exists before running configure."
    fi
    chmod +x "$AI_COMMAND_FILE"
    success "'ai' executable is ready."

    # --- Hook 'exec' function into shell profile ---
    info "Hooking 'ai' command via exec function into your shell profile..."
    local shell_profile="$HOME/.bashrc"; if [[ -n "$ZSH_VERSION" ]]; then shell_profile="$HOME/.zshrc"; fi; touch "$shell_profile"
    
    local ABS_AI_COMMAND_FILE; ABS_AI_COMMAND_FILE="$(pwd)/ai"
    
    cat <<EOF >> "$shell_profile"

# --- Load AI v58 Exec Hook ---
if [ -f "$ABS_AI_COMMAND_FILE" ]; then
    ai() {
        exec "$ABS_AI_COMMAND_FILE" "\$@"
    }
fi
EOF
    success "Shell 'exec' hook configured in $shell_profile."

    # --- Final Instructions ---
    echo ""; success "${ICON_CLEAN} Configuration complete! Your repository is ready.";
    info "The 'ai' command is now hooked into your shell."
    info "To activate the new system, please restart your shell or run:"; echo -e "  ${BOLD}${GREEN}source $shell_profile${RESET}"
}

# --- Uninstaller ---
uninstall() {
    header "AI v58 System Uninstaller"
    warn "This will remove the generated './.ai-cache' directory and the hook from your shell profile."
    warn "It will NOT remove the 'ai' script or other repo files."
    read -p "Proceed? [y/N]: " -r confirm; if [[ ! "$confirm" =~ ^[Yy]$ ]]; then info "Cancelled."; exit 0; fi
    sanitize_environment # This function does all the necessary cleaning
    info "Removing local AI cache..."; rm -rf "./.ai-cache";
    success "Uninstallation complete. Please restart your shell."
}

# --- Configurator Entrypoint ---
if [[ "$1" == "--uninstall" ]]; then uninstall; else configure_repo; fi
