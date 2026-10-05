#!/usr/bin/env python3
"""
bw-cloak-sync.py — Import and synchronize TOTP tokens from Bitwarden/Vaultwarden exports into Cloak/SOPS.

Supports:
- Bitwarden Authenticator JSON export (items[].login.totp)
- Standard Bitwarden vault export (items[].login.totp, items[].fields)
- Merging with existing SOPS modules/secrets.yaml (.cloak section)
- Auto-updating ~/.cloak/accounts for instant CLI access via 'cloak view <account>'
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
SECRETS_FILE = os.path.join(REPO_ROOT, "modules/secrets.yaml")
CLOAK_RUNTIME_FILE = os.path.expanduser("~/.cloak/accounts")


def parse_otpauth_uri(uri: str):
    """Parse otpauth:// URI and return dict with secret, issuer, algo, etc."""
    if not uri.startswith("otpauth://"):
        return None
    parsed = urllib.parse.urlparse(uri)
    params = urllib.parse.parse_qs(parsed.query)

    secret = params.get("secret", [""])[0].replace(" ", "").upper()
    if not secret:
        return None

    issuer = params.get("issuer", [""])[0]
    path_label = urllib.parse.unquote(parsed.path.lstrip("/"))

    if not issuer and ":" in path_label:
        issuer = path_label.split(":", 1)[0].strip()

    algo = params.get("algorithm", ["SHA1"])[0].upper()
    digits = params.get("digits", ["6"])[0]
    period = params.get("period", ["30"])[0]

    return {
        "secret": secret,
        "issuer": issuer or path_label,
        "path_label": path_label,
        "algorithm": algo,
        "digits": digits,
        "period": period,
    }


def clean_slug(name: str) -> str:
    """Clean name into a standard cloak account slug."""
    s = name.strip()
    # Strip protocol / www
    s = re.sub(r"^https?://", "", s, flags=re.I)
    s = re.sub(r"^www\.", "", s, flags=re.I)
    # Strip trailing usernames / emails like :jisifu@gmail.com
    if ":" in s:
        s = s.split(":", 1)[0].strip()
    if "@" in s:
        s = s.split("@", 1)[0].strip()
    # Strip domain extensions .com, .net, .org, .io, .lan
    s = re.sub(r"\.(com|net|org|io|dev|lan|app)$", "", s, flags=re.I)
    # Lowercase & sanitize
    s = s.lower()
    s = re.sub(r"[^a-z0-9_-]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s or "unnamed"


def extract_entries_from_json(json_data):
    """Extract TOTP entries from Bitwarden Authenticator or Vaultwarden JSON."""
    results = []

    # Handle standard items array
    items = json_data.get("items", [])
    if not items and isinstance(json_data, list):
        items = json_data

    for item in items:
        name = item.get("name", "Unnamed")
        login = item.get("login", {})
        totp_uri = login.get("totp") if isinstance(login, dict) else None

        # Check fields array if login.totp not present
        if not totp_uri and "fields" in item:
            for field in item.get("fields", []):
                val = field.get("value", "")
                if val.startswith("otpauth://"):
                    totp_uri = val
                    break

        if totp_uri:
            parsed = parse_otpauth_uri(totp_uri)
            if parsed:
                results.append({
                    "original_name": name,
                    "slug": clean_slug(name),
                    **parsed
                })

    return results


def load_existing_sops_cloak(secrets_file):
    """Read existing .cloak TOML section from SOPS."""
    try:
        out = subprocess.check_output(
            ["sops", "-d", secrets_file],
            stderr=subprocess.DEVNULL
        ).decode("utf-8")
        yq_proc = subprocess.run(
            ["yq", "-r", ".cloak"],
            input=out,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=True
        )
        cloak_toml = yq_proc.stdout
        accounts = {}
        curr = None
        for line in cloak_toml.splitlines():
            line_str = line.strip()
            if line_str.startswith("[") and line_str.endswith("]"):
                curr = line_str[1:-1]
                accounts[curr] = {"lines": []}
            elif curr and "=" in line_str:
                k, v = [x.strip() for x in line_str.split("=", 1)]
                v_clean = v.strip('"\'')
                accounts[curr][k] = v_clean
                accounts[curr]["lines"].append(line_str)
        return accounts, cloak_toml
    except Exception as e:
        print(f"Warning: could not read existing SOPS cloak section ({e})", file=sys.stderr)
        return {}, ""


def to_toml_string(accounts_dict):
    """Format accounts dictionary into clean cloak TOML format."""
    lines = []
    for slug in sorted(accounts_dict.keys()):
        data = accounts_dict[slug]
        lines.append(f"[{slug}]")
        key = data.get("key", "").upper()
        lines.append(f'key = "{key}"')
        totp_val = "true" if str(data.get("totp", "true")).lower() == "true" else "false"
        lines.append(f"totp = {totp_val}")
        hash_fn = data.get("hash_function", "SHA1").upper()
        lines.append(f'hash_function = "{hash_fn}"')
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def main():
    parser = argparse.ArgumentParser(description="Synchronize Bitwarden/Vaultwarden TOTP export with Cloak / SOPS.")
    parser.add_argument("export_file", nargs="?", default="", help="Path to bitwarden_authenticator_export.json")
    parser.add_argument("--apply", action="store_true", help="Apply merged cloak config directly to modules/secrets.yaml via SOPS")
    parser.add_argument("--print", action="store_true", help="Print resulting cloak TOML to stdout")
    parser.add_argument("--diff", action="store_true", help="Show accounts added or updated")

    args = parser.parse_args()

    input_file = args.export_file
    if not input_file:
        # Default auto-discovery in security directory
        candidates = [
            "/srv/data/security/bitwarden_authenticator_export_20250805190720.json",
            "/Volumes/data/security/bitwarden_authenticator_export_20250805190720.json",
        ]
        # Also check for newest export in security/
        sec_dir = "/srv/data/security" if os.path.isdir("/srv/data/security") else "/Volumes/data/security"
        if os.path.isdir(sec_dir):
            exports = [os.path.join(sec_dir, f) for f in os.listdir(sec_dir) if "bitwarden" in f.lower() and f.endswith(".json")]
            if exports:
                exports.sort(key=os.path.getmtime, reverse=True)
                candidates.insert(0, exports[0])

        for c in candidates:
            if os.path.isfile(c):
                input_file = c
                break

    if not input_file or not os.path.isfile(input_file):
        print(f"Error: Bitwarden export file not found. Specify path as argument.", file=sys.stderr)
        sys.exit(1)

    print(f"Reading Bitwarden export from: {input_file}")
    with open(input_file, "r", encoding="utf-8") as f:
        try:
            raw_data = json.load(f)
        except Exception as e:
            print(f"Error parsing JSON from {input_file}: {e}", file=sys.stderr)
            sys.exit(1)

    extracted = extract_entries_from_json(raw_data)
    print(f"Discovered {len(extracted)} TOTP entries in export.")

    existing_accounts, raw_toml = load_existing_sops_cloak(SECRETS_FILE)
    print(f"Existing Cloak accounts in SOPS: {len(existing_accounts)}")

    # Map known aliases and existing accounts by key
    key_to_existing_slug = {}
    for slug, data in existing_accounts.items():
        if "key" in data:
            key_to_existing_slug[data["key"].upper()] = slug

    # Special well-known alias overrides
    ALIAS_MAP = {
        "DirectAdmin": "x10hosting",
        "Synology DSM": "wetnose",
        "Synology DSM secondary": "synology",
        "CryptPad:shaoyan ji@pad.envs.net": "cryptpad",
    }

    added = []
    updated = []
    merged_accounts = dict(existing_accounts)

    for item in extracted:
        secret = item["secret"]
        orig_name = item["original_name"]

        # Check if secret already exists under any slug
        if secret in key_to_existing_slug:
            slug = key_to_existing_slug[secret]
        elif orig_name in ALIAS_MAP:
            slug = ALIAS_MAP[orig_name]
        else:
            slug = item["slug"]

        entry = {
            "key": secret,
            "totp": "true",
            "hash_function": item["algorithm"],
        }

        if slug not in merged_accounts:
            added.append((slug, orig_name))
            merged_accounts[slug] = entry
        else:
            # Check if key changed
            if merged_accounts[slug].get("key", "").upper() != secret:
                updated.append((slug, orig_name))
                merged_accounts[slug] = entry

    print(f"\nSummary: {len(added)} new account(s) to add, {len(updated)} updated.")
    if added:
        print("  New accounts:")
        for s, o in added:
            print(f"    + [{s}] (from '{o}')")
    if updated:
        print("  Updated accounts:")
        for s, o in updated:
            print(f"    ~ [{s}] (from '{o}')")

    new_toml = to_toml_string(merged_accounts)

    if args.print:
        print("\n=== Resulting Cloak TOML ===")
        print(new_toml)

    if args.apply:
        if not added and not updated:
            print("\nSOPS cloak configuration is already fully up to date.")
        else:
            print("\nApplying changes to modules/secrets.yaml via SOPS...")
            tmp_toml = os.path.join(REPO_ROOT, "modules", "cloak.tmp.toml")
            tmp_yaml = os.path.join(REPO_ROOT, "modules", "secrets.tmp.yaml")
            with open(tmp_toml, "w") as tf:
                tf.write(new_toml)

            # Decrypt existing secrets.yaml to temporary file in modules/
            with open(tmp_yaml, "w") as yf:
                subprocess.run(["sops", "-d", SECRETS_FILE], stdout=yf, check=True)

            # Update .cloak block using Go yq load_str
            subprocess.run(["yq", "e", f'.cloak = load_str("{tmp_toml}")', "-i", tmp_yaml], check=True)

            # Re-encrypt with sops in place
            subprocess.run(["sops", "-e", "-i", tmp_yaml], cwd=REPO_ROOT, check=True)

            # Atomically replace secrets.yaml
            os.replace(tmp_yaml, SECRETS_FILE)
            if os.path.exists(tmp_toml):
                os.remove(tmp_toml)

            print("✓ Successfully updated and re-encrypted modules/secrets.yaml with SOPS.")

            # Update runtime ~/.cloak/accounts if it exists or is symlinked
            try:
                target_paths = [
                    os.path.realpath(CLOAK_RUNTIME_FILE),
                    os.path.expanduser("~/.config/sops-nix/secrets/cloak"),
                ]
                for p in set(target_paths):
                    if os.path.exists(p):
                        try:
                            # Temporarily make writable
                            os.chmod(p, 0o600)
                            with open(p, "w") as cf:
                                cf.write(new_toml)
                            os.chmod(p, 0o400)
                            print(f"✓ Updated active cloak runtime accounts at {p}.")
                        except Exception as pe:
                            print(f"Notice: could not update {p}: {pe}", file=sys.stderr)
                    elif not os.path.exists(CLOAK_RUNTIME_FILE):
                        os.makedirs(os.path.dirname(CLOAK_RUNTIME_FILE), exist_ok=True)
                        with open(CLOAK_RUNTIME_FILE, "w") as cf:
                            cf.write(new_toml)
                        print(f"✓ Initialized {CLOAK_RUNTIME_FILE}.")
            except Exception as ce:
                print(f"Notice: runtime cloak update skipped ({ce}). sops-nix will update on rebuild.", file=sys.stderr)

    elif not args.print and not args.diff:
        print("\nRun with '--apply' to merge and encrypt into modules/secrets.yaml.")
        print("Run with '--print' to view the formatted TOML.")


if __name__ == "__main__":
    main()
