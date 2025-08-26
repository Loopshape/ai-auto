#!/usr/bin/env bash
set -eo pipefail
shopt -s nullglob

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$BASE_DIR/ai-auto"
TMP_DIR="$REPO_DIR/tmp"
MODEL_DIR="$REPO_DIR/models"
CDN_DIR="$REPO_DIR/cdnlibs"
MODEL="gemma3:1b"

TOP_LOG="$TMP_DIR/top.log"
PROGRESS_LOG="$TMP_DIR/progress.log"
mkdir -p "$TMP_DIR" "$MODEL_DIR" "$CDN_DIR"

# Flags
UPDATE_CDN=false
BUILD_MODE=false
ONE_FILE=""
CODE_PROMPT=""
IMPRO_MODE=false
TALK_MODE=false

# Terminal split heights
TERM_HEIGHT=$(tput lines)
TOP_HEIGHT=$((TERM_HEIGHT*20/100))
MID_HEIGHT=$((TERM_HEIGHT*40/100))
BOT_HEIGHT=$((TERM_HEIGHT - TOP_HEIGHT - MID_HEIGHT))

log_top() { echo "$(date '+%H:%M:%S') $*" >> "$TOP_LOG"; }
log_mid() { echo "$(date '+%H:%M:%S') $*" >> "$PROGRESS_LOG"; }

clear_terminal() { clear; }

refresh_view() {
    clear_terminal
    echo "=== AI Verbose Top ==="
    tail -n "$TOP_HEIGHT" "$TOP_LOG" 2>/dev/null
    echo "=== AI Progress Mid ==="
    tail -n "$MID_HEIGHT" "$PROGRESS_LOG" 2>/dev/null
    echo "=== User Input Bottom ==="
}

# Parse CLI flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--update) UPDATE_CDN=true; shift ;;
        -b|--build) BUILD_MODE=true; shift ;;
        -o|--one) ONE_FILE="$2"; shift 2 ;;
        -c|--code) CODE_PROMPT="$2"; shift 2 ;;
        -i|--impro) IMPRO_MODE=true; shift ;;
        -t|--talk) TALK_MODE=true; shift ;;
        *) shift ;;
    esac
done

# CDN Downloads (conditional)
cdn_download() {
    local lib="$1" url="$2" lib_dir="$CDN_DIR/$lib"
    mkdir -p "$lib_dir"
    if [ "$UPDATE_CDN" = true ] || [ ! -f "$lib_dir/$lib.min.js" ]; then
        curl -s -o "$lib_dir/$lib.min.js" "$url" && log_mid "$lib downloaded"
    else
        log_mid "$lib exists, skipping download"
    fi
}

cdn_download "jquery" "https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js"
cdn_download "gsap" "https://cdn.jsdelivr.net/npm/gsap@3.13.0/dist/gsap.min.js"
cdn_download "bootstrap5" "https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"

# Model backup
backup_model() {
    local src_model="$HOME/.ollama/models/$MODEL"
    if [ -d "$src_model" ]; then
        cp -r "$src_model" "$MODEL_DIR/" 2>/dev/null
        log_mid "Model $MODEL backed up"
    else
        log_mid "No local model found, skipping backup"
    fi
}
backup_model

# --- AI REPL ---
ai_repl() {
    log_mid "Starting AI REPL..."
    while true; do
        refresh_view
        read -rp "[AI]> " CMD

        [[ "$CMD" == "exit" ]] && break
        [[ "$CMD" == "space" ]] && log_mid "AI tilted by spacebar" && continue
        [[ "$CMD" =~ ^set\ .* ]] && eval_flags "$CMD" && continue

        if [ "$BUILD_MODE" = true ] || [ -n "$ONE_FILE" ] || [ -n "$CODE_PROMPT" ] || [ "$IMPRO_MODE" = true ]; then
            # AI code generation path
            local prompt="$CMD"
            [ -n "$CODE_PROMPT" ] && prompt="$CODE_PROMPT"
            [ -n "$ONE_FILE" ] && prompt="Generate file $ONE_FILE with: $prompt"
            [ "$IMPRO_MODE" = true ] && prompt="Automate task for: $prompt"
            if ! ollama run "$MODEL" "$prompt" 2>&1 | while read line; do log_top "$line"; done; then
                log_mid "AI execution failed, suggesting fix..."
                ollama run "$MODEL" "Suggest fix for: $prompt" 2>&1 | while read line; do log_top "$line"; done
            fi
        else
            # Shell execution first
            if [[ "$CMD" =~ ^(ls|cat|bash|cd|pwd|echo) ]]; then
                eval "$CMD" 2>&1 | while read line; do log_top "$line"; done
            else
                if ! ollama run "$MODEL" "$CMD" 2>&1 | while read line; do log_top "$line"; done; then
                    log_mid "AI execution failed, providing verbose suggestion..."
                    ollama run "$MODEL" "Suggest fix for: $CMD" 2>&1 | while read line; do log_top "$line"; done
                fi
            fi
        fi
    done
}

# --- Dynamic Flag Switch in REPL ---
eval_flags() {
    local args=($*)
    for arg in "${args[@]:1}"; do
        case "$arg" in
            build) BUILD_MODE=true ;;
            nbuild) BUILD_MODE=false ;;
            talk) TALK_MODE=true ;;
            strict) TALK_MODE=false ;;
            impro) IMPRO_MODE=true ;;
            noimpro) IMPRO_MODE=false ;;
        esac
    done
    log_mid "Flags updated: build=$BUILD_MODE talk=$TALK_MODE impro=$IMPRO_MODE"
}

# Start REPL
ai_repl