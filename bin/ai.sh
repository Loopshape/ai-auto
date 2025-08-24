#!/usr/bin/env bash
#
# AI Code Assistant v25.1
# AI-AUTO Framework – A sophisticated, AI-driven shell script automation framework
# that optimizes developer workflows with cognitive assistance, batch processing, and
# strategic planning.
#

# --- Strict Mode & Initial Setup ---
set -eo pipefail # Exit on error, but not on pipe failures within loops
shopt -s nullglob # Expands globs to nothing if no match is found

# --- Default Configuration (can be overridden by environment variables) ---
: "${MODEL:="gemma:2b"}" # Use gemma:2b if MODEL is not set
: "${CHUNK_SIZE:=50}"    # Default batch size, kept smaller for mobile compatibility
: "${EDITOR:="nano"}"    # Default editor for the 'update' command

# --- Global State Variables ---
VERSION="25.1"
COMMAND=""
USER_PROMPT=""
STRATEGIZE=false
INTERACTIVE=false
CONFIRM_CHANGES=false
SHARED_CONTEXT=""
AI_QUOTA=""
declare -a FILE_QUEUE=()
declare -A INSTRUCTIONS_CACHE # Associative array for .ai_instructions

# --- Core Utility Functions ---
log() {
  printf "\e[34m[AI Assistant]\e[0m %s\n" "$*" >&2
}

warn() {
  printf "\e[33m[AI Assistant] WARNING:\e[0m %s\n" "$*" >&2
}

error() {
  printf "\e[31m[AI Assistant] ERROR:\e[0m %s\n" "$*" >&2
  exit 1
}

usage() {
  cat << EOF
AI Code Assistant v$VERSION - AI-AUTO Framework

A sophisticated, AI-driven shell script automation framework.

USAGE:
  $(basename "$0") <command> [options] [files...]

CORE COMMANDS:
  edit        Apply a custom prompt to one or more files. (Default)
  build       Construct interconnected files from a high-level goal.
  rebuild     Rebuild scripts for robustness, readability, and modern syntax.
  format      Reformat code according to standard conventions.
  test        (Under development) Preview prompts without applying changes.
  update      Edit and update the assistant script itself.

GLOBAL OPTIONS:
  -p, --prompt          Require confirmation before applying each change.
  --strategize          Generate a strategic plan before execution.
  --interactive         Pause for approval after generating a strategic plan.
  --quota QUOTA         Set AI's architectural focus (e.g., "security", "performance").
  -c, --context "..."   Provide a shared context string for all files.
  -m, --model MODEL     Override default AI model (default: $MODEL).
  -h, --help            Show this help message.

EXAMPLES:
  # Reformat a single file
  $(basename "$0") format src/main.js

  # Rebuild all JS files, asking for confirmation on each
  $(basename "$0") rebuild -p src/**/*.js

  # Strategize a new feature build, then wait for approval to proceed
  $(basename "$0") build --strategize --interactive src/ "Add a new user login module"
EOF
}

# --- Prerequisite Check ---
check_deps() {
  for cmd in ollama git diff; do
    if ! command -v "$cmd" &>/dev/null; then
      error "'$cmd' command not found. Please install it to continue."
    fi
  done
}

# --- File & Instruction Handling ---
parse_instructions() {
  local instructions_file=".ai_instructions"
  if [ ! -f "$instructions_file" ]; then
    return
  fi
  while IFS=':' read -r pattern instruction || [[ -n "$pattern" ]]; do
    # Trim whitespace
    pattern=$(echo "$pattern" | xargs)
    instruction=$(echo "$instruction" | xargs)
    if [[ -n "$pattern" && ! "$pattern" =~ ^# ]]; then
      INSTRUCTIONS_CACHE["$pattern"]="$instruction"
    fi
  done < "$instructions_file"
}

get_instruction_for_file() {
  local file="$1"
  local matched_instruction=""
  # Iterate through patterns to find the best match
  for pattern in "${!INSTRUCTIONS_CACHE[@]}"; do
    if [[ "$file" == $pattern ]]; then
      matched_instruction="${INSTRUCTIONS_CACHE[$pattern]}"
    fi
  done
  echo "$matched_instruction"
}

# --- Core AI Interaction ---
run_ai() {
  local full_prompt="$1"
  local model_override="$2"
  local effective_model="${model_override:-$MODEL}"

  if ! ollama run "$effective_model" "$full_prompt" 2>/dev/null; then
      warn "AI command failed for model '$effective_model'. Trying a fallback..."
      if ! ollama run "gemma:2b" "$full_prompt"; then
          error "AI command failed with both primary and fallback models."
      fi
  fi
}


# --- Main Processing Logic ---
main() {
  check_deps
  parse_instructions

  # --- Argument Parsing ---
  while [[ $# -gt 0 ]]; do
    case "$1" in
      edit|build|rebuild|format|test|update)
        [[ -z "$COMMAND" ]] && COMMAND="$1" || FILE_QUEUE+=("$1")
        shift
        ;;
      -p|--prompt)
        CONFIRM_CHANGES=true
        shift
        ;;
      --strategize)
        STRATEGIZE=true
        shift
        ;;
      --interactive)
        INTERACTIVE=true
        shift
        ;;
      --quota)
        AI_QUOTA="$2"
        shift 2
        ;;
      -c|--context)
        SHARED_CONTEXT="$2"
        shift 2
        ;;
      -m|--model)
        MODEL="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        error "Unknown option: $1"
        ;;
      *)
        # Capture the user prompt or file paths
        if [[ -z "$COMMAND" || "$COMMAND" == "edit" || "$COMMAND" == "build" ]] && [[ -z "$USER_PROMPT" ]] && ! [[ -f "$1" || -d "$1" ]]; then
          USER_PROMPT="$1"
        else
          FILE_QUEUE+=("$1")
        fi
        shift
        ;;
    esac
  done

  # --- Command Handling ---
  COMMAND=${COMMAND:-edit} # Default to 'edit'

  case "$COMMAND" in
    update)
      log "Opening the assistant script for editing with $EDITOR..."
      $EDITOR "$0"
      log "Script updated. Please restart to apply changes."
      exit 0
      ;;
    test)
      log "The 'test' command is currently under re-architecture. Use 'edit' with '-p' for safe previews."
      exit 0
      ;;
  esac

  if [ ${#FILE_QUEUE[@]} -eq 0 ]; then
    error "No files specified. See usage with '-h'."
  fi

  log "Starting command '$COMMAND' on ${#FILE_QUEUE[@]} files with model '$MODEL'."

  # --- Archive Setup ---
  ARCHIVE_DIR=".ai_cache/$(date +%Y-%m-%d_%H-%M-%S)"
  mkdir -p "$ARCHIVE_DIR/originals"
  log "Outputs and backups will be archived in: $ARCHIVE_DIR"

  # --- Strategize Phase ---
  STRATEGIC_PLAN=""
  if [ "$STRATEGIZE" = true ]; then
    log "Generating strategic plan..."
    local plan_prompt="Based on the goal \"$USER_PROMPT\", the shared context \"$SHARED_CONTEXT\", and the file list provided, generate a concise, step-by-step technical plan for a senior developer to execute. Files: ${FILE_QUEUE[*]}. Focus on: ${AI_QUOTA:-general best practices}."
    STRATEGIC_PLAN=$(run_ai "$plan_prompt" "$MODEL")
    
    echo -e "\n\e[1m--- AI Strategic Plan ---\e[0m"
    echo "$STRATEGIC_PLAN"
    echo -e "\e[1m-------------------------\e[0m\n"

    if [ "$INTERACTIVE" = true ]; then
      read -p "Do you approve this plan and wish to proceed? [Y/n] " approval
      if [[ ! "$approval" =~ ^([yY][eE][sS]|[yY]|)$ ]]; then
        log "Plan rejected by user. Aborting."
        exit 0
      fi
    fi
  fi

  # --- Batch Processing Phase ---
  local failed_files=()
  local batch_num=1
  for batch_chunk in $(printf "%s\n" "${FILE_QUEUE[@]}" | xargs -n "$CHUNK_SIZE"); do
    log "Processing chunk #$batch_num..."
    for file in $batch_chunk; do
      if [ ! -f "$file" ]; then
        warn "Skipping '$file' (not found or not a regular file)."
        continue
      fi

      log "Processing: $file"
      
      # Determine the final prompt for this file
      local file_instruction
      file_instruction=$(get_instruction_for_file "$file")
      local final_prompt="$USER_PROMPT"

      if [[ -n "$file_instruction" ]]; then
        final_prompt="$file_instruction"
        log "  -> Using file-specific instruction from .ai_instructions"
      fi

      # Construct the full context for the AI
      local base_prompt
      case "$COMMAND" in
        rebuild) base_prompt="Rebuild the following script for maximum robustness, readability, and modern syntax. Apply best practices mercilessly." ;;
        format)  base_prompt="Reformat the following code according to standard conventions for its language. Do not add or remove logic." ;;
        build)   base_prompt="Your high-level goal is: '$USER_PROMPT'. Now, generate the content for the file '$file' as part of this goal." ;;
        *)       base_prompt="Apply the following instruction to the code: '$final_prompt'." ;;
      esac
      
      local full_ai_prompt="SYSTEM CONTEXT:
- Shared Context: ${SHARED_CONTEXT:-Not provided}
- Architectural Quota: ${AI_QUOTA:-Not provided}
- Strategic Plan: ${STRATEGIC_PLAN:-Not provided}

TASK: $base_prompt

FILE CONTENT:
\`\`\`
$(cat "$file")
\`\`\`

YOUR RESPONSE SHOULD ONLY CONTAIN THE FULL, UPDATED CODE FOR THE FILE. DO NOT INCLUDE EXPLANATIONS OR APOLOGIES.
"
      
      # Backup original file
      cp "$file" "$ARCHIVE_DIR/originals/$(basename "$file").bak"
      
      # Run AI and get new content
      local ai_output
      ai_output=$(run_ai "$full_ai_prompt" "$MODEL")
      
      # Sanitize AI output (remove markdown code fences)
      local sanitized_output
      sanitized_output=$(echo "$ai_output" | sed -e '1s/^```[a-zA-Z]*//' -e '$s/^```$//')

      # Save AI output for archival
      echo "$ai_output" > "$ARCHIVE_DIR/$(basename "$file").ai_response"
      
      # Create a temporary file for the diff
      local temp_file
      temp_file=$(mktemp)
      echo "$sanitized_output" > "$temp_file"
      
      # Show diff and confirm
      log "  -> Generating diff..."
      if git diff --no-index --color=always "$file" "$temp_file"; then
        log "  -> AI made no changes to the file."
        rm "$temp_file"
        continue
      fi

      local apply=true
      if [ "$CONFIRM_CHANGES" = true ]; then
        read -p "Apply these changes to '$file'? [Y/n] " confirm
        if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY]|)$ ]]; then
          apply=false
        fi
      fi

      if [ "$apply" = true ]; then
        mv "$temp_file" "$file"
        log "  -> Changes applied."
      else
        failed_files+=("$file")
        rm "$temp_file"
        log "  -> Changes skipped by user."
      fi
    done
    ((batch_num++))
  done

  log "Processing complete."
  if [ ${#failed_files[@]} -gt 0 ]; then
    warn "The following files were not modified due to user choice or an error: ${failed_files[*]}"
  fi
}

# --- Script Entrypoint ---
main "$@"