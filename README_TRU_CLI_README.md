# tru-cli + getbalance/getinfo — install guide

Two deliverables that together give you a bitcoin-cli-style experience for TRU:

1. **Patch 31** (`apply_tru_fixes_31.py`) — adds `getbalance` and `getinfo` aggregate RPC methods to the node.
2. **`tru-cli.cpp`** — a standalone command-line client that talks to the node's JSON-RPC.

Both are additive. Patch 31 changes no existing behavior; tru-cli is a brand-new binary. Neither is a consensus change, so this does **not** require a fresh genesis or coordinating the other nodes — it only affects the machine you build it on.

---

## Step 1 — Add the two RPC methods (patch 31)

```bash
cd ~/NEW_TRU        # wherever apply_tru_fixes_31.py is
python3 apply_tru_fixes_31.py --dry-run     # preview
python3 apply_tru_fixes_31.py               # apply (writes .p31.bak)
```

Reversible: `python3 apply_tru_fixes_31.py --revert`

This inserts two handlers into `src/rpc_server.cpp` and registers them in the dispatch:

- **`getbalance`** — params `{ "address": "<optional>" }`. With no address it uses the wallet's current address. Returns `{ address, confirmed (8-dp TRU string), satoshis }`. Uses the node's own `calculate_balance()`, so it matches every other balance readout, and formats TRU as a fixed 8-decimal string so large fractional balances never round.
- **`getinfo`** — returns `{ version, blocks, bestblockhash, chainsize, difficulty, difficultyhex, connections, chainvalid, address, balance, balance_sat }`.

## Step 2 — Add the tru-cli build target

Copy the client into your source tree and append the CMake target:

```bash
cp tru-cli.cpp ~/NEW_TRU/src/tru-cli.cpp
cat tru-cli.CMakeLists.snippet.txt >> ~/NEW_TRU/CMakeLists.txt
```

## Step 3 — Build

```bash
cd ~/NEW_TRU
./rebuild.sh
```

`tru-cli` lands in `build-native/bin/` alongside your other binaries. (The node itself is also rebuilt, which is what activates the new RPC methods from step 1.)

---

## Usage

Run against the local node (defaults to `127.0.0.1:8332`):

```bash
cd ~/NEW_TRU/build-native/bin

./tru-cli getinfo
./tru-cli getbalance
./tru-cli getbalance 1Fyuq4Nzy65isRXwcbpaHaZJbcGPkS57hb
./tru-cli getblockcount
./tru-cli getchaininfo
./tru-cli getconnectioncount
./tru-cli getpeerinfo
```

`getinfo` prints:

```
version       TRU-node
blocks        960
bestblockhash 04e9c0..aa
difficulty    0x1e00ffff (503382015)
connections   2
chainvalid    yes
chainsize     961
address       1Fyuq4Nzy65isRXwcbpaHaZJbcGPkS57hb
balance       7599.99990000 TRU
```

### Talk to a remote node

```bash
./tru-cli -rpcconnect=137.184.68.43 getblockcount
./tru-cli -rpcconnect=137.184.68.43 -rpcport=8332 getinfo
```

### Read connection details from a config file

```bash
./tru-cli -conf=~/NEW_TRU/build-native/bin/tru.conf getinfo
```
(reads `rpcconnect`/`node.ip` and `rpcport`/`node.port` if present)

### Raw passthrough — call ANY node method

tru-cli ships friendly wrappers for the common methods, but you can reach every method the node exposes via `raw`:

```bash
./tru-cli raw gettokenmetadata '{"tokenID":"cottage"}'
./tru-cli raw listunspent '{"address":"1Fyuq4Nzy65isRXwcbpaHaZJbcGPkS57hb"}'
./tru-cli raw getblocktemplate
./tru-cli raw verifytokenbalance '{"address":"1Fyuq4...","tokenID":"cottage"}'
```

### Options

| option | meaning | default |
|---|---|---|
| `-rpcconnect=<ip>` | node IP | 127.0.0.1 |
| `-rpcport=<port>` | node port | 8332 |
| `-conf=<file>` | read ip/port from a tru.conf-style file | — |
| `-json` | print raw JSON result instead of a summary | off |
| `-timeout=<sec>` | read timeout | 30 |
| `-h`, `--help` | full command list | — |

### Exit codes
- `0` success
- `1` transport error (node unreachable / bad JSON)
- `2` RPC error (method not found, bad params, etc.)

So you can script it: `./tru-cli getblockcount || echo "node down"`.

---

## Friendly commands → RPC methods

| tru-cli command | node method |
|---|---|
| `getinfo` | `getinfo` (new, patch 31) |
| `getbalance [address]` | `getbalance` (new, patch 31) |
| `getblockcount` | `getblockcount` |
| `getchaininfo` | `getchaininfo` |
| `getbestblockhash` | `getchaininfo` → bestHash |
| `getdifficulty` | `getchaininfo` → difficulty |
| `getpeerinfo` | `getpeerinfo` |
| `getconnectioncount` | `getpeerinfo` → count |
| `getnewaddress` | `getnewaddress` |
| `listaddresses` | `listaddresses` |
| `listunspent <addr>` | `listunspent` |
| `listtransactions <addr>` | `listtransactions` |
| `getblock <hash>` | `getblock` |
| `getblockbyheight <h>` | `getblockbyheight` |
| `gettransaction <txid>` | `gettransaction` |
| `getrawmempool` | `getrawmempool` |
| `getmininginfo` | `getminerstatus` |
| `gettokenmetadata <id>` | `gettokenmetadata` |
| `verifytokenbalance <addr> <id>` | `verifytokenbalance` |
| `raw <method> [json]` | any method |

---

## Notes / caveats

- **No RPC auth.** Your node's `/rpc` endpoint has no HTTP authentication, so tru-cli doesn't send credentials. If you ever put the RPC port on a public interface, front it with Cloudflare Access or a firewall — anyone who can reach `:8332` can call these methods. For local use over `127.0.0.1` this is fine.
- **`getbalance` is coin balance**, i.e. spendable TRU for an address (matches `calculate_balance`). Token holdings are separate — use `gettokenmetadata` / `verifytokenbalance` for those.
- **`version` is a placeholder string** (`"TRU-node"`). If you add a real version constant to the node later, change the one line in `handleGetInfo` to emit it.
- This was verified by compiling tru-cli.cpp against httplib 0.15.3 + nlohmann/json 3.11.3 and exercising every command against a node-shaped mock RPC server (summaries, address override, -json, raw passthrough, and both error paths).
