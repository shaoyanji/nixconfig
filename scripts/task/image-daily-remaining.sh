#!/usr/bin/env bash
# image-daily-remaining.sh — the day's allowance as a bare number
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"

remaining
