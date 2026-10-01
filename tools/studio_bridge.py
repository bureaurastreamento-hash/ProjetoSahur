"""Usa a ponte MCP local existente; exporta resultados para arquivo sem truncar."""
import argparse
import json
from pathlib import Path
import urllib.request
import uuid

def call(name, arguments):
    body = json.dumps({"id": str(uuid.uuid4()), "args": {name: arguments}}).encode()
    request = urllib.request.Request("http://127.0.0.1:44755/proxy", body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response: return json.load(response)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--code-file")
    parser.add_argument("--play", choices=["start_play", "stop", "run_server"])
    parser.add_argument("--output", default="/tmp/studio-bridge-result.json")
    args = parser.parse_args()
    state = call("GetStudioMode", {})
    print("Studio:", state["response"])
    if args.play: result = call("StartStopPlay", {"mode": args.play})
    elif args.code_file: result = call("RunCode", {"command": Path(args.code_file).read_text()})
    else: result = state
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print("Resultado:", args.output, "sucesso:", result["success"])
    if not result["success"]: raise SystemExit(1)

if __name__ == "__main__": main()
