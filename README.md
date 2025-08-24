Here’s the fully concatenated, detailed Git README in Markdown, ready for copy-paste, including all sections (summary, installation, features, commands, batch processing, advanced prompts, Termux support, and examples):

# AI Code Assistant v25.1

**AI-AUTO Framework** – A sophisticated, AI-driven shell script automation framework that optimizes developer workflows with cognitive assistance, batch processing, and strategic planning.

---

## Table of Contents

1. [Summary](#summary)
2. [Installation](#installation)
3. [Characteristics](#characteristics)
4. [Core Commands](#core-commands)
5. [Batch Processing & Chunking](#batch-processing--chunking)
6. [File-Specific Instructions](#file-specific-instructions)
7. [Strategize & Interactive Mode](#strategize--interactive-mode)
8. [Termux & Mobile Environment Support](#termux--mobile-environment-support)
9. [Examples](#examples)
10. [License](#license)

---

## Summary

The AI Code Assistant automates shell-based code editing, rebuilding, and formatting tasks. Its architecture combines:

- **Intelligent Chunking** – splits large batches into manageable chunks.
- **Resilient Processing** – retries only failed chunks.
- **Cognitive Features** – strategic planning, reasoning, and interactive prompts.
- **Hardened Modular Core** – stable, maintainable, and production-ready.

It evolves from simple automation into a cognitive agent capable of reasoning about files, applying nuanced instructions, and integrating with media and environment context.

---

## Installation

### Prerequisites

- Linux/Termux/Android with Bash/Zsh
- `curl`, `jq`, `ollama` CLI
- Git (optional for diff and version control)
- `nano` or your preferred editor for self-updates

### Clone and Set Up

```bash
git clone https://github.com/yourusername/ai-code-assistant.git
cd ai-code-assistant
chmod +x ai-assistant.sh

Optional: Add to PATH

ln -s $(pwd)/ai-assistant.sh /usr/local/bin/ai-assistant

Pull Default AI Model

ollama pull gemma3:1b


---

Characteristics

Full AI-driven scripting assistant

Single-file and batch operations

Modular, extensible prompts

File-specific instruction overrides

Context-aware processing including local media scanning

Automated backup and archiving of all AI outputs

Cross-platform support, including Termux



---

Core Commands

Command	Description

edit	Apply a custom prompt to one or more files. Default command.
build	Construct interconnected files from a high-level goal.
rebuild	Rebuild scripts for robustness, readability, and modern syntax.
format	Reformat code according to standard conventions.
test	Preview prompts without applying changes (currently re-architected).
update	Edit and update the assistant script itself.


Global Options

-p, --prompt – Require confirmation before applying changes.

--strategize – Generate a strategic plan first.

--interactive – Pause for approval between plan phases.

--quota QUOTA – Set AI's architectural focus.

-c, --context "..." – Provide a shared context string.

-m, --model MODEL – Override default AI model.

-h, --help – Show help message.



---

Batch Processing & Chunking

Automatically splits large file batches into smaller chunks (CHUNK_SIZE, default 500).

Works with queue-reloop logic: retries only failed chunks.

Maintains context and instructions across files.

Example: process 1200 files in 3 chunks:


./ai-assistant.sh rebuild src/**/*.js

Each file is archived and optionally diffed before final application.



---

File-Specific Instructions

.ai_instructions Format

# Pattern : Instruction
src/main.js : Optimize all loops for performance and readability
src/utils/*.js : Ensure all functions have proper JSDoc comments
src/api/*.js : Convert callbacks to async/await and add error handling

Supports glob patterns

Overrides default AI prompt per file

Works in both single-file and batch mode


Example Usage

Edit Single File

./ai-assistant.sh edit src/main.js "Refactor main function for readability"

Rebuild Multiple Files

./ai-assistant.sh rebuild src/**/*.js

Each file receives its corresponding .ai_instructions prompt

Changes are archived and previewed



---

Strategize & Interactive Mode

--strategize generates a step-by-step AI plan

--interactive allows user approval between phases

Compatible with edit and build commands

Context and instructions are combined for smarter AI reasoning:


./ai-assistant.sh --strategize build src/ "Add logging and error handling"


---

Termux & Mobile Environment Support

Fully functional in Termux on Android

Respects mobile memory and CPU limits

CHUNK_SIZE can be reduced for low-resource devices:


export CHUNK_SIZE=100
./ai-assistant.sh rebuild src/**/*.js

Supports local media scanning for mobile projects



---

Examples

Reformat Single File

./ai-assistant.sh format src/main.js

Apply Shared Context to Batch

./ai-assistant.sh -c "Project-wide configuration: enable strict mode" edit src/**/*.js "Apply coding standards"

Strategize and Build

./ai-assistant.sh --strategize build src/ "Generate all frontend HTML/CSS components"


---

License

MIT License – Free to use and modify.

This README now **covers everything**:

- Detailed **summary & characteristics**
- Installation instructions for Linux/Termux
- Command references
- Batch processing & chunking explanations
- `.ai_instructions` file usage
- Strategize & interactive mode
- Examples of all major operations

It’s fully self-contained for **copy-paste into your Git repository**.  

If you want, I can also generate a **shortened "Quick Start" version** for immediate project onboarding. Do you want me to create that too?

