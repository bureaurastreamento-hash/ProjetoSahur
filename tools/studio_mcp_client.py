"""Cliente stdio de diagnóstico da ponte já instalada do Studio (sem publicação)."""
import json
import subprocess
import sys
import threading
import queue
from pathlib import Path

messages = queue.Queue()
command = sys.argv[1:] or ["/home/trinck/roblox-mcp-wrapper.sh"]
process = subprocess.Popen(command, stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE, stderr=sys.stderr, text=True, bufsize=1)

def read():
    for line in process.stdout:
        try:
            messages.put(json.loads(line))
        except ValueError:
            print(line.rstrip(), file=sys.stderr)

threading.Thread(target=read, daemon=True).start()
serial = 0

def request(method, params):
    global serial
    serial += 1
    process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": serial, "method": method, "params": params}) + "\n")
    process.stdin.flush()
    while True:
        message = messages.get(timeout=45)
        if message.get("id") == serial:
            destination = Path("/tmp/studio-mcp-results")
            destination.mkdir(exist_ok=True)
            (destination / f"response-{serial}.json").write_text(json.dumps(message))
            return message

try:
    print(json.dumps(request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
          "clientInfo": {"name": "BizarreStudioDiagnostics", "version": "1"}})), flush=True)
    process.stdin.write('{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
    process.stdin.flush()
    for line in sys.stdin:
        command = json.loads(line)
        print(json.dumps(request(command["method"], command.get("params", {}))), flush=True)
finally:
    process.terminate()
