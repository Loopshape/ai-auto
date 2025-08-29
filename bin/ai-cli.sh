#!/bin/bash
set -e
echo "🚀 Starting Mindmap AI Full Auto Installer..."

BASE_DIR="$HOME/mindmap_ai"
AI_DIR="$BASE_DIR/ai_workers"
NODE_DIR="$BASE_DIR/node_controller"
FRONTEND_DIR="$BASE_DIR/frontend"
ENV_FILE="$HOME/.env"

# --- 1. Directories ---
mkdir -p "$AI_DIR" "$NODE_DIR" "$FRONTEND_DIR"
echo "✅ Project directories created"

# --- 2. Environment ---
echo "GEMINI_API_KEY='AIzaSyD4eva8xXXqFmXvE_t3WTYjMJOZrE4LTU0'" > "$ENV_FILE"
echo "✅ .env created"

# --- 3. Ensure Python3 symlink ---
if ! command -v python3 &>/dev/null; then
    apt update && apt install -y python3 python3-venv python3-pip
fi
ln -sf $(command -v python3) /usr/local/bin/python
echo "✅ Python3 ready"

# --- 4. Node.js ---
if ! command -v node &>/dev/null; then
    apt install -y nodejs npm
fi
echo "✅ Node.js ready"

# --- 5. Ollama / Gemini ---
OLLAMA_DIR="/opt/ollama"
mkdir -p "$OLLAMA_DIR"
if ! command -v ollama &>/dev/null; then
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        curl -L -o "$OLLAMA_DIR/ollama" "https://ollama.com/downloads/ollama-linux-arm64"
    else
        curl -L -o "$OLLAMA_DIR/ollama" "https://ollama.com/downloads/ollama-linux-x86_64"
    fi
    chmod +x "$OLLAMA_DIR/ollama"
    ln -sf "$OLLAMA_DIR/ollama" /usr/local/bin/ollama
fi
echo "✅ Ollama installed"

# --- 6. Python AI Workers ---
for i in 1 2 3; do
    WORKER="$AI_DIR/worker$i"
    mkdir -p "$WORKER"
    python3 -m venv "$WORKER/venv"
    "$WORKER/venv/bin/pip" install --upgrade pip
    "$WORKER/venv/bin/pip" install fastapi uvicorn pydantic python-dotenv google-generativeai
    cat > "$WORKER/ai_worker.py" << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()
try:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not found")
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel('gemma3:1b')
except Exception as e:
    print(f"Failed to configure Gemini: {e}")
    model = None

class Prompt(BaseModel):
    text: str

@app.post("/generate")
async def generate(prompt: Prompt):
    if not model:
        raise HTTPException(status_code=503, detail="Gemini model not initialized")
    response = model.generate_content(f"Mindmap assistant. Topic: {prompt.text}")
    return {"original_prompt": prompt.text, "ai_response": response.text.strip()}
EOF
done
echo "✅ Python AI workers ready"

# --- 7. Node.js Controller ---
cd "$NODE_DIR"
npm init -y >/dev/null
npm install express axios >/dev/null
cat > "api_controller.js" << 'EOF'
const express = require('express');
const axios = require('axios');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const PORT = 3000;
const AI_WORKER_PORTS = [5000,5001,5002];
let currentWorkerIndex = 0;

app.use(express.json());
app.use(express.static(path.join(__dirname,'../frontend')));

function speak(text){
    exec(`espeak-ng "${text.replace(/"/g,'\\"')}"`, (e,s,o)=>{});
}

app.post('/api/mindmap', async (req,res)=>{
    const {prompt,speakResponse}=req.body;
    const port=AI_WORKER_PORTS[currentWorkerIndex];
    currentWorkerIndex=(currentWorkerIndex+1)%AI_WORKER_PORTS.length;
    try{
        const response=await axios.post(`http://localhost:${port}/generate`,{text:prompt});
        if(speakResponse && response.data.ai_response) speak(response.data.ai_response);
        res.json(response.data);
    }catch(e){
        res.status(500).send({error:'AI worker failed'});
    }
});

app.listen(PORT,()=>console.log(`Controller at http://localhost:${PORT}`));
EOF
cd "$BASE_DIR"
echo "✅ Node.js controller ready"

# --- 8. Frontend ---
cat > "$FRONTEND_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Mindmap AI</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.2/gsap.min.js"></script>
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
</head>
<body>
<h1>Mindmap AI</h1>
<input id="prompt" placeholder="Enter topic">
<button id="generate">Generate</button>
<script src="dynamicPagesXML.js"></script>
</body>
</html>
EOF

cat > "$FRONTEND_DIR/dynamicPagesXML.js" << 'EOF'
$('#generate').click(async()=>{
    const val=$('#prompt').val();
    const resp=await fetch('/api/mindmap',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt:val,speakResponse:true})});
    const data=await resp.json();
    alert(`AI Response: ${data.ai_response}`);
});
EOF
echo "✅ Frontend ready"

# --- 9. Run all ---
cat > "$BASE_DIR/run_all.sh" << 'EOF'
#!/bin/bash
pkill ollama 2>/dev/null || true
ollama serve &
for i in 1 2 3; do
    PORT=$((4999+i))
    DIR="ai_workers/worker$i"
    "$DIR/venv/bin/uvicorn" ai_worker:app --port $PORT --host 0.0.0.0 > "worker_$PORT.log" 2>&1 &
done
cd node_controller
node api_controller.js > ../controller.log 2>&1 &
cd ..
echo "✅ Mindmap AI running at http://localhost:3000"
EOF
chmod +x "$BASE_DIR/run_all.sh"

echo "🎉 Full auto-install complete! Run './run_all.sh' to start the full system."