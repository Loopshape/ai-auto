#!/usr/bin/env bash
# ========================================================
# 🎯 AI Code Assistant v25.1 - GitHub-Ready Complete
# ========================================================
# Features: Single-File & Batch Modes, Chunking, Logging, Backup, Strategize & Interactive
# Model: Ollama Gemma series (auto-selected)
# Author: AI Code Lab
# ========================================================

set -euo pipefail

# --- Paths ---
: "${OLLAMA_API_URL:="http://localhost:11434"}"
CORE_DIR="$HOME/.ai_core"
BACKUP_DIR="$CORE_DIR/backups"
ARCHIVE_DIR="$CORE_DIR/archive"
LOG_DIR="$CORE_DIR/logs"
TEMP_DIR="$CORE_DIR/temp"
LOG_FILE="$LOG_DIR/events.log"

# --- Defaults ---
DEFAULT_MODEL="gemma3:1b"
MODEL="$DEFAULT_MODEL"
AUTO_CONFIRM=1
MAX_RELOOPS=3
CHUNK_SIZE=500
CONTEXT_STRING=""
STRATEGIZE_ENABLED=0
INTERACTIVE_ENABLED=0
STRATEGY_QUOTA="pipeline"
declare -g -A FILE_INSTRUCTION_MAP

# --- Prompt Templates ---
readonly PROMPT_TEMPLATE_EDIT_SINGLE="[CONTEXT_BLOCK][FILE_INSTRUCTION_BLOCK]Expert '[LANGUAGE]' programmer. Modify '[FILE]'.\n---\n[CONTENT]\n---\nUser Task: [USER_PROMPT]\nRespond ONLY with complete '[LANGUAGE]' code."
readonly PROMPT_TEMPLATE_REBUILD_SINGLE="[CONTEXT_BLOCK][FILE_INSTRUCTION_BLOCK]Expert script refactoring. Rebuild '[FILE]' robustly, readable, add error handling/comments. Do not change core.\n---\n[CONTENT]\n---\nRespond ONLY with rebuilt script in markdown."
readonly PROMPT_TEMPLATE_FORMAT_SINGLE="[CONTEXT_BLOCK][FILE_INSTRUCTION_BLOCK]Precise code formatter. Reformat '[FILE]' according to language conventions.\n---\n[CONTENT]\n---\nRespond ONLY with reformatted code in markdown."
readonly PROMPT_TEMPLATE_REBUILD_BATCH="Rebuild scripts robustly, readable, efficient, respecting dependencies."
readonly PROMPT_TEMPLATE_FORMAT_BATCH="Reformat files according to standard conventions."

# --- Utilities ---
fail() { echo -e "\n❌ Error: $1" >&2; exit 1; }
log_action() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options] [files|-] [prompt]

Commands:
  edit       Apply prompt to files (default)
  build      Build interconnected files from high-level goal
  rebuild    Rebuild scripts robustly
  format     Reformat code
  test       Show final prompt only
  update     Self-update script

Options:
  -p, --prompt       Confirm before applying changes
  --strategize       Generate strategic plan before execution
  --interactive      Pause between plan phases
  --quota QUOTA      Set AI focus
  -c, --context "..." Shared context string
  -m, --model MODEL  Specify Ollama model
  -h, --help         Show help
EOF
    exit 1
}

# --- Core Functions ---
self_update() {
    local TMP_FILE; TMP_FILE=$(mktemp "$TEMP_DIR/update.XXXXXX")
    echo "🖋️ Open editor to update script..."
    nano "$TMP_FILE"
    [[ -s "$TMP_FILE" ]] && mv -f "$TMP_FILE" "$0" && chmod +x "$0" && echo "🎉 Script updated." || { echo "❌ Update aborted."; rm -f "$TMP_FILE"; }
    exit 0
}

auto_select_best_model() {
    [[ "$MODEL" != "$DEFAULT_MODEL" ]] && { echo "ℹ️ Using model: $MODEL"; return; }
    local preferred=("gemma3:1b" "gemma2:latest" "gemma:2b")
    local installed; installed=$(ollama list | awk 'NR>1 {print $1}')
    for m in "${preferred[@]}"; do [[ $installed =~ $m ]] && { MODEL="$m"; echo "✅ Selected: $MODEL"; return; }; done
    echo "⚠️ Default '$DEFAULT_MODEL' missing, using fallback 'gemma2:latest'."
    MODEL="gemma2:latest"
}

load_file_instructions() {
    [[ -f ".ai_instructions" ]] || return
    echo "ℹ️ Loading '.ai_instructions'"
    while IFS= read -r line; do
        [[ "$line" =~ ^\s*# || -z "$line" ]] && continue
        local pattern="${line%%:*}" instruction="${line#*:}"
        FILE_INSTRUCTION_MAP["$pattern"]="$instruction"
    done < ".ai_instructions"
}

ensure_ollama_is_running() {
    curl -s --fail "$OLLAMA_API_URL" -o /dev/null || { echo "🔌 Starting Ollama..."; ollama serve & disown; sleep 2; }
}

get_language_from_filename() { echo "${1##*.}" | tr '[:upper:]' '[:lower:]'; }
scan_for_media() { find . -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.svg" -o -iname "*.mp4" -o -iname "*.mp3" \) -print; }

generate_code_from_prompt() {
    local prompt="$1"
    local payload; payload=$(jq -n --arg model "$MODEL" --arg prompt "$prompt" '{model:$model,prompt:$prompt,stream:true}')
    curl -s -X POST "$OLLAMA_API_URL/api/generate" -d "$payload"
}

process_single_file_instance() {
    local REAL_PATH="$1" DISPLAY_NAME="$2" GENERATED_CODE="$3"
    local TMP_FILE="$TEMP_DIR/$(basename "$DISPLAY_NAME" | tr -cd '[:alnum:]._-').tmp"
    printf "%s" "$GENERATED_CODE" > "$TMP_FILE"

    echo "🔍 Diff for $DISPLAY_NAME:"
    diff -u "$REAL_PATH" "$TMP_FILE" || true

    [[ "$AUTO_CONFIRM" -eq 1 ]] && CONFIRM="y" || read -p "Apply changes to $DISPLAY_NAME? [y/N]: " CONFIRM

    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        [[ -f "$REAL_PATH" ]] && cp "$REAL_PATH" "$BACKUP_DIR/$(basename "$REAL_PATH")_$(date '+%Y%m%d%H%M%S').bak"
        mv "$TMP_FILE" "$REAL_PATH"
        echo "✅ $DISPLAY_NAME updated."
    else
        rm "$TMP_FILE"
        echo "❌ Changes for $DISPLAY_NAME discarded."
    fi
}

run_single_file_mode() {
    local PROMPT="$1" REAL_PATH="$2" DISPLAY_NAME="$3"
    local LANG; LANG=$(get_language_from_filename "$DISPLAY_NAME")
    local CONTEXT_BLOCK=""; [[ -n "$CONTEXT_STRING" ]] && CONTEXT_BLOCK="Shared Context:\n---\n$CONTEXT_STRING\n---\n"
    local FILE_BLOCK=""; [[ -n "${FILE_INSTRUCTION_MAP[$REAL_PATH]}" ]] && FILE_BLOCK="File Instruction:\n---\n${FILE_INSTRUCTION_MAP[$REAL_PATH]}\n---\n"
    local FINAL_PROMPT="${PROMPT//\[CONTEXT_BLOCK\]/$CONTEXT_BLOCK}"
    FINAL_PROMPT="${FINAL_PROMPT//\[FILE_INSTRUCTION_BLOCK\]/$FILE_BLOCK}"
    FINAL_PROMPT="${FINAL_PROMPT//\[LANGUAGE\]/$LANG}"
    FINAL_PROMPT="${FINAL_PROMPT//\[FILE\]/$DISPLAY_NAME}"
    FINAL_PROMPT="${FINAL_PROMPT//\[CONTENT\]/$(cat "$REAL_PATH")}"

    local GENERATED; GENERATED=$(generate_code_from_prompt "$FINAL_PROMPT")
    process_single_file_instance "$REAL_PATH" "$DISPLAY_NAME" "$GENERATED"
}

run_batch_mode() {
    local BATCH_PROMPT="$1"; shift
    for FILE_PATH in "$@"; do
        local FNAME; FNAME=$(basename "$FILE_PATH")
        run_single_file_mode "$BATCH_PROMPT" "$FILE_PATH" "$FNAME"
    done
}

# --- Main ---
main() {
    mkdir -p "$BACKUP_DIR" "$ARCHIVE_DIR" "$LOG_DIR" "$TEMP_DIR"
    [[ $# -eq 0 ]] && usage
    auto_select_best_model
    load_file_instructions
    ensure_ollama_is_running

    COMMAND="${1:-edit}"; shift
    FILES=("$@")
    [[ ${#FILES[@]} -eq 0 ]] && fail "No files specified."

    case "$COMMAND" in
        edit) PROMPT="$PROMPT_TEMPLATE_EDIT_SINGLE" ;;
        rebuild) PROMPT="$PROMPT_TEMPLATE_REBUILD_SINGLE" ;;
        format) PROMPT="$PROMPT_TEMPLATE_FORMAT_SINGLE" ;;
        build) PROMPT="$PROMPT_TEMPLATE_REBUILD_BATCH" ;;
        *) fail "Unknown command: $COMMAND" ;;
    esac

    if [[ ${#FILES[@]} -eq 1 ]]; then
        run_single_file_mode "$PROMPT" "${FILES[0]}" "$(basename "${FILES[0]}")"
    else
        run_batch_mode "$PROMPT" "${FILES[@]}"
    fi
}

main "$@"