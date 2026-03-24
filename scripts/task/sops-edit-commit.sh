#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <secrets_dir> <encrypted_file> <commit_message>" >&2
  exit 1
fi

secrets_dir="$1"
encrypted_file="$2"
commit_message="$3"

sops edit "$secrets_dir/$encrypted_file"
(
  cd "$secrets_dir"
  git add "$encrypted_file"
  git commit -m "$commit_message"
  git push origin HEAD:master
)
