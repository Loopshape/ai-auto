# 🧠 AI Code Assistant v25.1

[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-25.1-blue.svg)]
[![GitHub Workflow](https://img.shields.io/github/actions/workflow/status/yourusername/ai-code-assistant/main.yml?branch=main)]()

**AI Code Assistant** ist ein industriestarker Shell-Skript-Assistent, der KI-gesteuerte Codebearbeitung, Formatierung und Refactoring direkt über die Kommandozeile ermöglicht. Unterstützt Single-File und Batch-Modus mit intelligentem Chunking.

---

## Inhaltsverzeichnis
- [Features](#features)
- [Installation](#installation)
- [Verwendung](#verwendung)
- [Beispiele](#beispiele)
- [Konfiguration](#konfiguration)
- [Lizenz](#lizenz)

---

## Features
- Single-File & Batch-Modus
- Intelligentes Chunking für große Dateimengen
- Backup & Archivierung vor Änderungen
- Diff-Vorschau vor Übernahme
- Strategize & Interactive Mode
- Ollama Gemma Modelle (auto-select)
- Selbst-Update Funktion
- Cross-File Kontext und Medienintegration

---

## Installation
```bash
# Clone the repository
git clone https://github.com/yourusername/ai-code-assistant.git
cd ai-code-assistant

# Make script executable
chmod +x ai-code-assistant.sh

# Optional: Add to PATH
sudo ln -s "$(pwd)/ai-code-assistant.sh" /usr/local/bin/ai-code-assistant