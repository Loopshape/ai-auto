# AI Code Assistant v25.1

**AI-AUTO Framework** – A sophisticated, AI-driven shell script automation framework that optimizes developer workflows with cognitive assistance, batch processing, and strategic planning.

---

## Table of Contents

1.  [Summary](#summary)
2.  [Installation](#installation)
3.  [Characteristics](#characteristics)
4.  [Core Commands](#core-commands)
5.  [Batch Processing & Chunking](#batch-processing--chunking)
6.  [File-Specific Instructions](#file-specific-instructions)
7.  [Strategize & Interactive Mode](#strategize--interactive-mode)
8.  [Termux & Mobile Environment Support](#termux--mobile-environment-support)
9.  [Examples](#examples)
10. [License](#license)

---

## Summary

The AI Code Assistant automates shell-based code editing, rebuilding, and formatting tasks. Its architecture combines:

-   **Intelligent Chunking** – splits large batches into manageable chunks.
-   **Resilient Processing** – retries only failed chunks.
-   **Cognitive Features** – strategic planning, reasoning, and interactive prompts.
-   **Hardened Modular Core** – stable, maintainable, and production-ready.

It evolves from simple automation into a cognitive agent capable of reasoning about files, applying nuanced instructions, and integrating with media and environment context.

---

## Installation

### Prerequisites

-   Linux/Termux/Android with Bash/Zsh
-   `curl`, `jq`, `ollama` CLI
-   Git (optional for diff and version control)
-   `nano` or your preferred editor for self-updates

### Clone and Set Up

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/ai-code-assistant.git
    cd ai-code-assistant
    ```

2.  **Make the script executable:**
    ```bash
    chmod +x ai-assistant.sh
    ```

3.  **Optional: Add to your system's PATH:**
    ```bash
    # This makes the assistant available from any directory
    sudo ln -s $(pwd)/ai-assistant.sh /usr/local/bin/ai-assistant
    ```

4.  **Pull the Default AI Model:**
    ```bash
    ollama pull gemma:2b
    ```

---

## Characteristics

-   Full AI-driven scripting assistant
-   Single-file and batch operations
-   Modular, extensible prompts
-   File-specific instruction overrides
-   Context-aware processing including local media scanning
-   Automated backup and archiving of all AI outputs
-   Cross-platform support, including Termux

---

## Core Commands

| Command | Description |
| :--- | :--- |
| `edit` | Apply a custom prompt to one or more files. This is the **default** command. |
| `build` | Construct interconnected files from a high-level goal. |
| `rebuild` | Rebuild scripts for robustness, readability, and modern syntax. |
| `format` | Reformat code according to standard conventions. |
| `test` | Preview prompts without applying changes (currently re-architected). |
| `update` | Edit and update the assistant script itself using your default editor. |

### Global Options

-   `-p`, `--prompt` – Require confirmation before applying changes to each file.
-   `--strategize` – Generate a strategic plan first before executing any file modifications.
-   `--interactive` – Pause for user approval after the strategic plan is generated.
-   `--quota QUOTA` – Set the AI's architectural focus (e.g., "security", "performance").
-   `-c`, `--context "..."` – Provide a shared context string to the AI for all operations.
-   `-m`, `--model MODEL` – Override the default AI model.
-   `-h`, `--help` – Show the help message.

---

## Batch Processing & Chunking

The assistant automatically splits large file batches into smaller chunks (`CHUNK_SIZE`, default 50) to ensure stability and manage memory, especially on mobile devices.

It works with queue-reloop logic: if a chunk fails, it can be retried without re-processing successful chunks. The assistant maintains context and instructions across all files in the batch.

**Example:** Process 1200 files in 24 chunks of 50:
```bash
./ai-assistant.sh rebuild src/**/*.js