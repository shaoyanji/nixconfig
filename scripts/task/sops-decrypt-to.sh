#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <encrypted_file> <output_path>" >&2
  exit 1
fi

encrypted_file="$1"
output_path="$2"

sops -d "$encrypted_file" > "$output_path"
