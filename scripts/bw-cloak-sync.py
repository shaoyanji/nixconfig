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


def extract_entries_from_toml(content: str):
    """Extract TOTP entries from existing Cloak TOML format."""
    results = []
    current_section = None
    sec_key = None
    sec_algo = "SHA1"

    for line in content.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            if current_section and sec_key:
                results.append({
                    "original_name": current_section,
                    "slug": clean_slug(current_section),
                    "secret": sec_key,
                    "algorithm": sec_algo,
                    "digits": "6",
                    "period": "30",
                })
            current_section = line[1:-1].strip()
            sec_key = None
            sec_algo = "SHA1"
        elif "=" in line and current_section:
            k, v = line.split("=", 1)
            k = k.strip().lower()
            v = v.strip().strip('"').strip("'")
            if k == "key":
                sec_key = v.upper()
            elif k == "hash_function":
                sec_algo = v.upper()

    if current_section and sec_key:
        results.append({
            "original_name": current_section,
            "slug": clean_slug(current_section),
            "secret": sec_key,
            "algorithm": sec_algo,
            "digits": "6",
            "period": "30",
        })

    return results


def decrypt_age_payload(file_path: str = None, raw_bytes: bytes = None) -> str:
    """Decrypt an age-encrypted file or payload in-memory without writing to disk."""
    key_candidates = [
        os.path.expanduser("~/.config/sops/age/tpm-identity.txt"),
        os.path.expanduser("~/.config/sops/age/keys.txt"),
        "/Volumes/data/security/secrets/sops/age/keys.txt",
        "/srv/data/security/secrets/sops/age/keys.txt",
        "/Volumes/data/security/secrets/key.txt",
        "/srv/data/security/secrets/key.txt",
        "/Volumes/data/security/secrets/USB Copy_2024-11-24_131715/age-key.txt",
        os.path.expanduser("~/.ssh/id_ed25519"),
    ]

    for k in key_candidates:
        if os.path.isfile(k):
            try:
                cmd = ["age", "-d", "-i", k]
                if file_path:
                    cmd.append(file_path)
                    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
                else:
                    proc = subprocess.run(cmd, input=raw_bytes, capture_output=True, text=True, check=True)
                if proc.stdout.strip():
                    return proc.stdout
            except subprocess.CalledProcessError:
                continue

    # Fallback to default age -d
    try:
        cmd = ["age", "-d"]
        if file_path:
            cmd.append(file_path)
            proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
        else:
            proc = subprocess.run(cmd, input=raw_bytes, capture_output=True, text=True, check=True)
        return proc.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error: Unable to decrypt age payload with available keys: {e.stderr.strip()}", file=sys.stderr)
        sys.exit(1)


def get_sops_env():
    """Resolve environment for sops commands, prioritizing tpm-identity.txt if present."""
    env = dict(os.environ)
    if not env.get("SOPS_AGE_KEY_FILE"):
        for candidate in [
            os.path.expanduser("~/.config/sops/age/tpm-identity.txt"),
            os.path.expanduser("~/.config/sops/age/keys.txt"),
        ]:
            if os.path.isfile(candidate):
                env["SOPS_AGE_KEY_FILE"] = candidate
                break
    return env


def load_existing_sops_cloak(secrets_file):
    """Read existing .cloak TOML section from SOPS."""
    try:
        out = subprocess.check_output(
            ["sops", "-d", secrets_file],
            env=get_sops_env(),
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
    parser.add_argument("export_file", nargs="?", default="", help="Path to JSON export, accounts.age, or '-' for stdin")
    parser.add_argument("--apply", action="store_true", help="Apply merged cloak config directly to modules/secrets.yaml via SOPS")
    parser.add_argument("--print", action="store_true", help="Print resulting cloak TOML to stdout")
    parser.add_argument("--diff", action="store_true", help="Show accounts added or updated")
    parser.add_argument("--export-age", nargs="?", const="/Volumes/data/security/accounts.age", help="Export existing SOPS cloak accounts to age-encrypted file")

    args = parser.parse_args()

    existing_accounts, raw_toml = load_existing_sops_cloak(SECRETS_FILE)

    if args.export_age:
        out_file = args.export_age
        print(f"Exporting {len(existing_accounts)} Cloak accounts from SOPS into encrypted file: {out_file}...")
        recipients = [
            "age1tsv2lurpjzyx9ng6hcc4dff23lvv7tqkyyxz5zlpx32egu2c9vfql9m008",  # devji
            "age1rt9xrc78y78p78da0vca0dz7vr3gf6g0vlzqss5e38mnjxkg4paqj4jxxl",  # frieren
        ]
        age_cmd = ["age"]
        for r in recipients:
            age_cmd.extend(["-r", r])
        age_cmd.extend(["-o", out_file])
        try:
            os.makedirs(os.path.dirname(os.path.abspath(out_file)), exist_ok=True)
            subprocess.run(age_cmd, input=raw_toml.encode("utf-8"), check=True)
            os.chmod(out_file, 0o600)
            print(f"✓ Successfully exported and encrypted {out_file} (multi-recipient devji + frieren, 0 plaintext on disk).")
            return
        except Exception as e:
            print(f"Error exporting encrypted age file: {e}", file=sys.stderr)
            sys.exit(1)

    input_file = args.export_file
    if not input_file and not sys.stdin.isatty():
        input_file = "-"

    if not input_file:
        # Default auto-discovery in security directory: prefer encrypted .age first!
        candidates = []
        for sdir in ["/srv/data/security", "/Volumes/data/security"]:
            if os.path.isdir(sdir):
                # 1. Encrypted files (.age)
                age_files = [
                    os.path.join(sdir, f) for f in os.listdir(sdir)
                    if f.endswith(".age") and any(k in f.lower() for k in ["account", "authenticator", "bitwarden"])
                ]
                candidates.extend(age_files)

                # 2. Plaintext exports/accounts if present
                json_files = [
                    os.path.join(sdir, f) for f in os.listdir(sdir)
                    if f.endswith(".json") and any(k in f.lower() for k in ["authenticator", "bitwarden", "vaultwarden"])
                ]
                if json_files:
                    json_files.sort(key=os.path.getmtime, reverse=True)
                    candidates.extend(json_files)
                acc_file = os.path.join(sdir, "accounts")
                if os.path.isfile(acc_file):
                    candidates.append(acc_file)

        for c in candidates:
            if os.path.isfile(c):
                input_file = c
                break

    if input_file == "-":
        print("Reading TOTP source from stdin (memory-only pipeline)...")
        file_content = sys.stdin.read()
    elif not input_file or not os.path.isfile(input_file):
        print(f"Error: TOTP export, accounts.age, or accounts file not found. Specify path or '-' for stdin.", file=sys.stderr)
        sys.exit(1)
    elif input_file.endswith(".age"):
        print(f"Reading age-encrypted source from: {input_file}")
        file_content = decrypt_age_payload(file_path=input_file)
    else:
        print(f"Reading TOTP source from: {input_file}")
        with open(input_file, "r", encoding="utf-8") as f:
            file_content = f.read()

    # If stream begins with age envelope
    if file_content.startswith("age-encryption.org/v1"):
        print("Detected age-encrypted stream. Decrypting in-memory...")
        file_content = decrypt_age_payload(raw_bytes=file_content.encode("utf-8"))

    extracted = []
    trimmed = file_content.strip()
    if trimmed.startswith("{") or (input_file != "-" and input_file.endswith(".json")):
        try:
            raw_data = json.loads(file_content)
            if isinstance(raw_data, dict) and raw_data.get("encrypted") is True:
                print("Error: Detected password-encrypted Bitwarden vault export.", file=sys.stderr)
                print("Hint: To import directly in-memory without plaintext files on disk, run:", file=sys.stderr)
                print("  bw export --format json | task dev:cloak:sync -", file=sys.stderr)
                sys.exit(1)
            extracted = extract_entries_from_json(raw_data)
        except Exception as e:
            print(f"Error parsing JSON from source: {e}", file=sys.stderr)
            sys.exit(1)

        if not extracted and input_file != "-":
            print(f"Warning: Discovered 0 TOTP entries in {input_file} (export may be empty).", file=sys.stderr)
            # Check for fallback accounts/accounts.age file in candidate dirs
            for sdir in ["/srv/data/security", "/Volumes/data/security"]:
                for fallback_candidate in ["accounts.age", "accounts"]:
                    f_path = os.path.join(sdir, fallback_candidate)
                    if os.path.isfile(f_path) and f_path != input_file:
                        print(f"Falling back to existing Cloak source: {f_path}")
                        if f_path.endswith(".age"):
                            f_content = decrypt_age_payload(file_path=f_path)
                        else:
                            with open(f_path, "r", encoding="utf-8") as ff:
                                f_content = ff.read()
                        extracted = extract_entries_from_toml(f_content)
                        if extracted:
                            break
                if extracted:
                    break
    else:
        # TOML format (like accounts or accounts.age)
        extracted = extract_entries_from_toml(file_content)

    print(f"Discovered {len(extracted)} TOTP entries in source.")
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
                subprocess.run(["sops", "-d", SECRETS_FILE], env=get_sops_env(), stdout=yf, check=True)

            # Update .cloak block using Go yq load_str
            subprocess.run(["yq", "e", f'.cloak = load_str("{tmp_toml}")', "-i", tmp_yaml], check=True)

            # Re-encrypt with sops in place
            subprocess.run(["sops", "-e", "-i", tmp_yaml], env=get_sops_env(), cwd=REPO_ROOT, check=True)

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
