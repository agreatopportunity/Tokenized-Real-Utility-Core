#!/usr/bin/env python3
import argparse
import json
import threading
import time
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

def main():
    ap = argparse.ArgumentParser(description="TRU one-shot side-branch getblocktemplate proxy")
    ap.add_argument("--parent", required=True, help="64-hex parent hash to mine on")
    ap.add_argument("--height", required=True, type=int, help="candidate block height")
    ap.add_argument("--bits", required=True, help="compact bits hex, e.g. 1e0098ec")
    ap.add_argument("--listen-port", type=int, default=39332)
    ap.add_argument("--real-port", type=int, default=38332)
    ap.add_argument("--subsidy", type=int, default=5_000_000_000)
    args = ap.parse_args()

    parent = args.parent.lower()
    bits = args.bits.lower().removeprefix("0x")
    if len(parent) != 64 or any(c not in "0123456789abcdef" for c in parent):
        raise SystemExit("ERROR: --parent must be exactly 64 hex chars")
    if not bits or any(c not in "0123456789abcdef" for c in bits):
        raise SystemExit("ERROR: --bits must be hex")
    if args.height <= 1:
        raise SystemExit("ERROR: --height must be > 1")

    real_url = f"http://127.0.0.1:{args.real_port}/rpc"
    accepted = {"hash": None}

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt, *vals):
            return

        def _send(self, status, body, ctype="application/json"):
            if isinstance(body, str):
                body = body.encode()
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            try:
                n = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(n)
                req = json.loads(raw.decode("utf-8"))
                method = req.get("method")
                req_id = req.get("id", 1)

                if method == "getblocktemplate":
                    result = {
                        "version": 0x20000000,
                        "previousblockhash": parent,
                        "curtime": int(time.time()),
                        "height": args.height,
                        "transactions": [],
                        "sizelimit": 64 * 1024 * 1024,
                        "assemblylimit": 56 * 1024 * 1024,
                        "bits": bits,
                        "coinbasevalue": args.subsidy,
                        "estimatedblockbytes": 4096,
                        "skippedforsize": 0,
                        "skippedinvalid": 0,
                    }
                    body = json.dumps({"jsonrpc":"2.0","id":req_id,"result":result}).encode()
                    self._send(200, body)
                    return

                fwd = urllib.request.Request(
                    real_url, data=raw,
                    headers={"Content-Type":"application/json"},
                    method="POST"
                )
                try:
                    with urllib.request.urlopen(fwd, timeout=30) as r:
                        body = r.read()
                        status = r.status
                        ctype = r.headers.get("Content-Type", "application/json")
                except urllib.error.HTTPError as e:
                    body = e.read()
                    status = e.code
                    ctype = e.headers.get("Content-Type", "application/json")

                self._send(status, body, ctype)

                if method == "submitblock" and status == 200:
                    try:
                        resp = json.loads(body.decode("utf-8"))
                        result = resp.get("result") or {}
                        if result.get("status") == "accepted":
                            accepted["hash"] = result.get("hash")
                            print(
                                f"\nPASS: node accepted side block "
                                f"height={args.height} hash={accepted['hash']}",
                                flush=True,
                            )
                            threading.Thread(
                                target=self.server.shutdown, daemon=True
                            ).start()
                    except Exception as e:
                        print(f"WARNING: could not parse submitblock response: {e}", flush=True)

            except Exception as e:
                msg = json.dumps({
                    "jsonrpc":"2.0",
                    "id":None,
                    "error":{"code":-32099,"message":str(e)}
                })
                try:
                    self._send(500, msg)
                except Exception:
                    pass

    server = ThreadingHTTPServer(("127.0.0.1", args.listen_port), Handler)
    print("TRU one-shot side-branch template proxy", flush=True)
    print(f"  listen: 127.0.0.1:{args.listen_port}", flush=True)
    print(f"  real RPC: {real_url}", flush=True)
    print(f"  parent: {parent}", flush=True)
    print(f"  height: {args.height}", flush=True)
    print(f"  bits:   {bits}", flush=True)
    print(f"  subsidy:{args.subsidy}", flush=True)
    print("  mode: coinbase-only; shuts down after first accepted submitblock", flush=True)
    server.serve_forever(poll_interval=0.2)
    server.server_close()

    if accepted["hash"]:
        print(f"FINAL_ACCEPTED_HASH={accepted['hash']}", flush=True)
    else:
        print("Proxy stopped without an accepted block.", flush=True)

if __name__ == "__main__":
    main()
