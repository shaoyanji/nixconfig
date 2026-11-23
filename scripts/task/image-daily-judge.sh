#!/usr/bin/env bash
# image-daily-judge.sh PATH — judge one file with agy and print the verdict
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


cmd_judge() {
  need jq agy
  local path=${1:?usage: image-daily.sh judge PATH [lane]}
  [ -f "$path" ] || die "$path does not exist"
  "$(image_daily_cli)" judge --png "$(readlink -f "$path")" --lane "${2:-wall}" --intent "$(lane_setting "${2:-wall}" intent)"
  echo
}

cmd_judge "$@"
