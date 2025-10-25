#!/usr/bin/env python3
# mdns_fast_check.py
# Fast Bonjour presence check for a .local name.
# Prints YES/NO. Exit 0 on YES, 1 on NO, 2 on error.

import argparse, os, re, signal, subprocess, sys, threading, time

IPV4_ANYWHERE = re.compile(r'(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)')

def main():
    ap = argparse.ArgumentParser(description="Fast mDNS (.local) presence check via dns-sd.")
    ap.add_argument("name", help="mDNS name, e.g. diskserver.local")
    ap.add_argument("--timeout", type=float, default=1.0, help="Seconds to wait (default: 1.0)")
    ap.add_argument("--mode", choices=["v4", "v4v6"], default="v4",
                    help='Query mode for dns-sd -G (default: v4). Use v4v6 if host may reply AAAA first.')
    ap.add_argument("--dns-sd", default="dns-sd", help="Path to dns-sd binary (default: dns-sd)")
    ap.add_argument("--debug", action="store_true", help="Echo dns-sd lines to stderr")
    args = ap.parse_args()

    # Launch dns-sd
    try:
        proc = subprocess.Popen(
            [args.dns_sd if hasattr(args, "dns_sd") else args.dns-sd, "-G", args.mode, args.name],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            start_new_session=True,  # new process group so we can kill it cleanly
        )
    except FileNotFoundError:
        print("ERROR: dns-sd not found.", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    present = {"ok": False}
    done = threading.Event()

    def reader():
        try:
            for line in proc.stdout:
                s = line.strip()
                if args.debug:
                    print(f"[dns-sd] {s}", file=sys.stderr)
                # Only consider additions; ignore removals or status chatter
                if " Add " not in s:
                    continue
                # If we see any IPv4 in the line, call it present
                if IPV4_ANYWHERE.search(s):
                    present["ok"] = True
                    break
                # In v4v6 mode, consider any Add line as "present" even if IPv6 only
                if args.mode == "v4v6":
                    present["ok"] = True
                    break
        finally:
            done.set()

    t = threading.Thread(target=reader, daemon=True)
    t.start()

    # Wait up to timeout
    done.wait(args.timeout)

    # Cleanup dns-sd
    try:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            for _ in range(20):
                if proc.poll() is not None:
                    break
                time.sleep(0.01)
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass

    if present["ok"]:
        print("YES")
        return 0
    else:
        print("NO")
        return 1

if __name__ == "__main__":
    sys.exit(main())
