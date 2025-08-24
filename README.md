Here’s a Quick Start README version, stripped down to essentials for immediate onboarding, still in Markdown:

# AI Code Assistant v25.1 – Quick Start

**AI-AUTO Framework** – AI-driven automation for shell-based scripting tasks with batch processing and cognitive reasoning.

---

## Installation

```bash
git clone https://github.com/yourusername/ai-code-assistant.git
cd ai-code-assistant
chmod +x ai-assistant.sh
ln -s $(pwd)/ai-assistant.sh /usr/local/bin/ai-assistant
ollama pull gemma3:1b

Supports Linux, Termux, and Android.


---

Basic Commands

Command	Usage

edit	Edit one or more files with AI prompt
rebuild	Rebuild scripts for readability & robustness
format	Reformat code to standard conventions
build	Generate files from a high-level goal
update	Edit & update the assistant itself


Options

-p – Confirm before applying changes

-c "context" – Provide shared context

--strategize – Generate step-by-step AI plan

--interactive – Pause for approval between plan phases



---

Examples

Single File Edit

./ai-assistant.sh edit src/main.js "Refactor main function for readability"

Batch Rebuild

./ai-assistant.sh rebuild src/**/*.js

Using Shared Context

./ai-assistant.sh -c "Enable strict mode" edit src/**/*.js "Apply coding standards"

Strategize Mode

./ai-assistant.sh --strategize build src/ "Generate all frontend components"


---

Advanced Usage

Use .ai_instructions to provide file-specific prompts.

Supports Termux; adjust CHUNK_SIZE for low-resource devices.

Changes are archived, diffed, and optionally confirmed.


export CHUNK_SIZE=100
./ai-assistant.sh rebuild src/**/*.js


---

This Quick Start guide lets developers get up and running in minutes with AI-assisted automation, batch processing, and smart scripting workflows.

This version is **concise, copy-paste ready**, and ideal for fast onboarding while preserving the most important commands, options, and examples.  
