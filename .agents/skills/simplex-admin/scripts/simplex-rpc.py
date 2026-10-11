#!/usr/bin/env python3
"""
simplex-rpc: Declarative WebSocket JSON-RPC CLI for SimpleX Chat daemon.
Communicates directly with `simplex-chat -p <port>` daemon (default ws://127.0.0.1:5225).
"""

import argparse
import asyncio
import json
import sys
import uuid

try:
    import websockets
except ImportError:
    sys.stderr.write("Error: 'websockets' library required. Run via 'nix shell nixpkgs#python3Packages.websockets' or use declarative python environment.\n")
    sys.exit(1)


async def send_command(ws_url: str, command: str, timeout: float = 10.0):
    corr_id = str(uuid.uuid4())[:8]
    req = {"corrId": corr_id, "cmd": command}

    async with websockets.connect(ws_url) as ws:
        await ws.send(json.dumps(req))
        while True:
            resp_raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
            try:
                data = json.loads(resp_raw)
                # Filter for matching corrId or return general response
                if data.get("corrId") == corr_id:
                    return data
            except json.JSONDecodeError:
                return resp_raw


async def main():
    parser = argparse.ArgumentParser(description="SimpleX Chat WebSocket RPC Client")
    parser.add_argument("command", nargs="?", default="", help="Command to execute (e.g. '/members #Fleet', '/groups', '/chats')")
    parser.add_argument("--ws", default="ws://127.0.0.1:5225", help="WebSocket daemon URL")
    parser.add_argument("--send-group", metavar=("GROUP", "MSG"), nargs=2, help="Send message to a group (e.g. --send-group '#Fleet' 'hello')")
    parser.add_argument("--send-contact", metavar=("CONTACT", "MSG"), nargs=2, help="Send message to a contact (e.g. --send-contact '@devji' 'hello')")
    parser.add_argument("--members", metavar="GROUP", help="List members of a group")
    parser.add_argument("--raw", action="store_true", help="Output raw JSON")
    parser.add_argument("--timeout", type=float, default=10.0, help="Response timeout in seconds")

    args = parser.parse_args()

    cmd = args.command
    if args.send_group:
        grp, msg = args.send_group
        if not grp.startswith("#"):
            grp = f"#{grp}"
        cmd = f"{grp} {msg}"
    elif args.send_contact:
        contact, msg = args.send_contact
        if not contact.startswith("@"):
            contact = f"@{contact}"
        cmd = f"{contact} {msg}"
    elif args.members:
        grp = args.members
        if not grp.startswith("#"):
            grp = f"#{grp}"
        cmd = f"/members {grp}"

    if not cmd:
        parser.print_help()
        sys.exit(1)

    try:
        res = await send_command(args.ws, cmd, timeout=args.timeout)
        if args.raw or not isinstance(res, dict):
            print(json.dumps(res, indent=2) if isinstance(res, dict) else res)
        else:
            resp_body = res.get("resp", {})
            resp_type = resp_body.get("type") if isinstance(resp_body, dict) else None
            
            if resp_type == "groupMembers":
                group = resp_body.get("group", {}).get("groupInfo", {})
                members = resp_body.get("group", {}).get("members", []) or resp_body.get("members", [])
                print(f"Group: #{group.get('localDisplayName')} (ID: {group.get('groupId')})")
                print(f"Owner: {resp_body.get('user', {}).get('localDisplayName')}")
                print("Members:")
                for m in members:
                    name = m.get("localDisplayName") or m.get("memberProfile", {}).get("displayName")
                    role = m.get("memberRole")
                    status = m.get("memberStatus")
                    print(f"  - {name} [{role}] (status: {status})")
            else:
                print(json.dumps(res, indent=2))
    except Exception as e:
        sys.stderr.write(f"Error executing SimpleX command: {e}\n")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
