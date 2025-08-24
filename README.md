# AI Code Assistant v25.1

**AI Code Assistant** ist ein leistungsstarkes CLI-Tool, das große Batch-Dateien, Refactoring und Formatierung mit KI-Unterstützung automatisiert. Die Version 25.1 integriert intelligente **Chunking-Strategien**, **Streaming-API-Generierung**, **Backup & Archivierung**, und optionalen **Strategize Mode** für geplante, genehmigte KI-Ausführung.

---

## Inhaltsverzeichnis

1. [Installation](#installation)
2. [Hauptmerkmale](#hauptmerkmale)
3. [Architektur & Workflow](#architektur--workflow)
4. [Befehle & Optionen](#befehle--optionen)
5. [Beispiele](#beispiele)
6. [Termux-Nutzung](#termux-nutzung)
7. [Lizenz](#lizenz)

---

## Installation

### Voraussetzungen

- Linux / macOS / Termux (Android)
- `bash`, `curl`, `jq`, `realpath`, `find`, `nano` oder ein anderer Editor
- Ollama AI-Server (`ollama serve`) installiert

```bash
# Für Termux
pkg install bash curl jq coreutils findutils nano
curl -fsSL https://ollama.com/install.sh | sh