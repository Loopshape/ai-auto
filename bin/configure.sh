#!/bin/bash
set -e

USER_HOME="$HOME"
PROJECT_DIR="$USER_HOME/mindmap_ai"
ENV_FILE="$USER_HOME/.env"
GEMINI_API_KEY="AIzaSyD4eva8xXXqFmXvE_t3WTYjMJOZrE4LTU0"

mkdir -p "$PROJECT_DIR/ai_workers" "$PROJECT_DIR/node_controller" "$PROJECT_DIR/frontend"

echo "GEMINI_API_KEY=$GEMINI_API_KEY" > "$ENV_FILE"

pkg update -y
pkg install -y python3 nodejs git curl espeak-ng npm fakeroot

curl -s https://ollama.com/install.sh | bash || true
pkill ollama 2>/dev/null || true
ollama serve &

for i in 1 2 3; do
    WORKER_DIR="$PROJECT_DIR/ai_workers/worker$i"
    mkdir -p "$WORKER_DIR"
    python3 -m venv "$WORKER_DIR/venv"
    "$WORKER_DIR/venv/bin/pip" install --upgrade pip
    "$WORKER_DIR/venv/bin/pip" install fastapi uvicorn pydantic google-generativeai python-dotenv

    cat > "$WORKER_DIR/ai_worker.py" <<'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os, json
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()
app = FastAPI()
api_key=os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)
model=genai.GenerativeModel('gemma3:1b')

OFFLINE_CACHE=os.path.expanduser("~/.mindmap_offline.json")
POOL_FILE=os.path.expanduser("~/.mindmap_pools.json")
if not os.path.exists(OFFLINE_CACHE): 
    with open(OFFLINE_CACHE,"w") as f: json.dump([],f)
if not os.path.exists(POOL_FILE):
    with open(POOL_FILE,"w") as f: json.dump({},f)

class Prompt(BaseModel):
    text: str
    mime: str = "text/plain"

@app.post("/generate")
async def generate_node(prompt: Prompt):
    try:
        full_prompt = f"You are a mindmap assistant. Given '{prompt.text}', generate a concise sub-topic."
        ai_text = model.generate_content(full_prompt).text.strip().replace("\n"," ")

        try:
            with open(POOL_FILE,"r") as f: pools=json.load(f)
            pool_idx=str(abs(hash(ai_text))%8)
            if pool_idx not in pools: pools[pool_idx]=[]
            pools[pool_idx].append({"text":ai_text,"mime":prompt.mime})
            with open(POOL_FILE,"w") as f: json.dump(pools,f)
        except:
            with open(OFFLINE_CACHE,"r") as f: offline=json.load(f)
            offline.append({"text":ai_text,"mime":prompt.mime})
            with open(OFFLINE_CACHE,"w") as f: json.dump(offline,f)
            pool_idx="offline"

        return {"original_prompt": prompt.text, "ai_response": ai_text, "pool_idx": pool_idx}
    except Exception as e:
        raise HTTPException(status_code=500,detail=str(e))
EOF
done

cd "$PROJECT_DIR/node_controller"
npm init -y >/dev/null
npm install express axios ws >/dev/null

cat > api_controller.js <<'EOF'
const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const PORT = 3000;
const AI_WORKER_PORTS=[5000,5001,5002];
let currentWorker=0;

app.use(express.json());
app.use(express.static(path.join(__dirname,'../frontend')));

const OFFLINE_FILE = process.env.HOME+'/.mindmap_offline.json';
const POOL_FILE = process.env.HOME+'/.mindmap_pools.json';

const server = http.createServer(app);
const wss = new WebSocket.Server({server});

function broadcastPools(){
    if(fs.existsSync(POOL_FILE)){
        const data = fs.readFileSync(POOL_FILE,'utf-8');
        wss.clients.forEach(client=>{
            if(client.readyState===WebSocket.OPEN) client.send(JSON.stringify({type:'pools',data:JSON.parse(data)}));
        });
    }
}

app.post('/api/mindmap',async(req,res)=>{
    const {prompt,mime,speakResponse}=req.body;
    const workerPort=AI_WORKER_PORTS[currentWorker];
    currentWorker=(currentWorker+1)%AI_WORKER_PORTS.length;
    try{
        const r=await axios.post(`http://localhost:${workerPort}/generate`,{text:prompt,mime:mime});
        if(speakResponse && r.data.ai_response) exec(`espeak-ng "${r.data.ai_response}"`);
        res.json(r.data);
        broadcastPools();
    }catch(e){res.status(500).send({error:e.message});}
});

app.get('/api/pools',(req,res)=>{
    if(fs.existsSync(POOL_FILE)) res.json(JSON.parse(fs.readFileSync(POOL_FILE,'utf-8')));
    else res.json({});
});

setInterval(async ()=>{
    if(!fs.existsSync(OFFLINE_FILE)) return;
    const offline = JSON.parse(fs.readFileSync(OFFLINE_FILE,'utf-8'));
    if(offline.length===0) return;
    for(const node of offline){
        const workerPort=AI_WORKER_PORTS[currentWorker];
        currentWorker=(currentWorker+1)%AI_WORKER_PORTS.length;
        try{await axios.post(`http://localhost:${workerPort}/generate`,{text:node.text,mime:node.mime});}catch(e){}
    }
    fs.writeFileSync(OFFLINE_FILE,'[]');
    broadcastPools();
},10000);

server.listen(PORT,()=>console.log(`Controller running at http://localhost:${PORT}`));
EOF

cd "$PROJECT_DIR"
curl -s -o frontend/gsap.min.js https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.2/gsap.min.js

# frontend/index.html omitted for brevity (same as before)

cat > run_workers.sh <<'EOF'
#!/bin/bash
for i in 1 2 3; do
    PORT=$((4999+i))
    WORKER_DIR="$PWD/ai_workers/worker$i"
    "$WORKER_DIR/venv/bin/uvicorn" ai_worker:app --port $PORT --host 0.0.0.0 --app-dir "$WORKER_DIR" > "worker_${PORT}.log" 2>&1 &
done
echo "Workers started in background."
EOF

cat > run_controller.sh <<'EOF'
#!/bin/bash
cd node_controller
node api_controller.js > "../controller.log" 2>&1 &
cd ..
echo "Controller started."
EOF

cat > run_all.sh <<'EOF'
#!/bin/bash
./run_workers.sh
./run_controller.sh
echo "All services started at http://localhost:3000"
EOF

chmod +x run_workers.sh run_controller.sh run_all.sh

echo "✅ Installation complete. Run './run_all.sh' to start everything."