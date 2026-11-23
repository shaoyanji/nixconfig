# image-publish — the image-daily pipeline's four agentScheduler slots. The
# scripts live in scripts/task/image-daily-*.sh (split from the monolith); this
# module owns only the schedule, the PATH the store-baked slot needs, and the
# share/reserve arithmetic wrapper. An edit to the schedule lands on frieren,
# the only host that enables it — it is a host service, not a chain feature.
{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.services.imagePublish;

  # The allowance is 100 images a day and the generator's burst limit is 25 an
  # hour, so one nightly pass spends the day in minutes and then answers 429 for
  # the rest of the hour. Four slots 6h20 apart each take an even share of what the
  # day has left — 25 at 01:10 on a fresh day, less when a hand-run batch already
  # spent some — which is the same 100 without the burst and cannot be spent twice.
  # Every slot republishes the Cloudinary manifest, so the asset frontend follows
  # the queue through the day, and each takes the roster's next unkept row with its
  # leftover, which is what makes "more wallpapers" a roster edit rather than a
  # supervised run. The last slot keeps 10 images back so an evening batch does not
  # start by finding the day already swept. Tools are prepended to PATH: cpg still
  # lives in the user profile, agy no longer does — the judge needs it from the
  # closure or every slot fails its verdict step.
  imageDailySlot = slot: total: reserve:
    pkgs.writeShellScript "image-daily-slot-${slot}" ''
      set -uo pipefail
      export PATH=${
        lib.makeBinPath [
          pkgs.jq
          pkgs.git
          pkgs.python3
          pkgs.curl
          pkgs.util-linux
          pkgs.findutils
          pkgs.coreutils
          pkgs.gnused
          pkgs.ffmpeg
          pkgs.bash
          pkgs.antigravity-cli
        ]
      }:"$PATH"
      export IMAGES_ROOT=/Volumes/data/pics/generated
      # The Cloudinary and xs helpers read secrets through lib/paths.sh, which takes
      # this as its repo root. The store copy of the source cannot carry it: the
      # apikeys plane has no committed mirror, so `modules/secrets/` only exists in
      # the checkout (and only with the submodule fetched). Pointing here is what
      # lets `publish` sign an upload from a store-baked script.
      export NIXCONFIG_ROOT=${user.home}/Documents/nixconfig
      export STORYBOOK_DIR=${user.home}/Documents/storybook/lantern
      export SLOT=${slot}
      export RESERVE=${toString reserve}
      # A slot spends the queue first, then the standing character roster with what
      # the slot's cap has left, and publishes once. The roster skips a row the
      # judge already kept, so a round cut short by the hourly burst resumes on the
      # next slot for free instead of waiting for someone to start it again. Neither
      # phase publishes alone: one publish at the end is one manifest rewrite, and
      # paths the manifest already serves are not uploaded twice.
      # The whole source root, not the one file: the script resolves its own
      # `../..` for the briefs, the roster, the Cloudinary and Pages helpers and
      # the asset frontend, and a lone store-baked script resolves to `/`.
      daily=${../../.}/scripts/task/image-daily.sh
      ledger=$IMAGES_ROOT/ledger.jsonl
      rc=0
      # One pool, shared: a slot takes its even share of what the day has left
      # across the slots still to run, so an early hand-run batch lowers the later
      # slots instead of being spent twice. The share arithmetic is the script's
      # own (`share`): it translates the "unlimited" plan answer into a day count,
      # refreshes a stale session token once, and deals the same cap that
      # `task images:today` prints for the next slot.
      slots_left=$(( ${toString total} - ${toString slot} + 1 ))
      cap=$(${pkgs.bash}/bin/bash "$daily" share "$slots_left" 2>/dev/null || printf 1)
      case $cap in "" | *[!0-9]*) cap=1 ;; esac
      before=$(wc -l <"$ledger" 2>/dev/null || printf 0)
      CAP=$cap PUBLISH=0 ${pkgs.bash}/bin/bash "$daily" run || rc=$?
      after=$(wc -l <"$ledger" 2>/dev/null || printf 0)
      room=$(( cap - (after - before) ))
      # What the queue left is the roster's, less the reserve this slot keeps back:
      # the script deducts a reserve inside `run` only, so a row loop given the
      # leftover would spend it down to zero.
      spare=$(${pkgs.bash}/bin/bash "$daily" remaining 2>/dev/null || printf 0)
      case $spare in "" | *[!0-9]*) spare=0 ;; esac
      spare=$(( spare - ${toString reserve} ))
      [ "$spare" -lt 0 ] && spare=0
      [ "$room" -gt "$spare" ] && room=$spare
      if [ "$room" -gt 0 ]; then
        MAX_GEN=$room PUBLISH=0 ${pkgs.bash}/bin/bash "$daily" plates || rc=$?
      fi
      ${pkgs.bash}/bin/bash "$daily" publish || rc=$?
      exit $rc
    '';
in {
  options.services.imagePublish = {
    enable =
      lib.mkEnableOption
      "the image-daily publish pipeline's four agentScheduler slots (queue, roster, Cloudinary manifest)";
  };

  # Composes into services.agentScheduler.jobs — the scheduler module must be
  # imported too, or this attrset has no option to merge into and eval fails
  # naming services.agentScheduler.
  config = lib.mkIf cfg.enable {
    services.agentScheduler.jobs = {
      # Four daytime slots, clear of 03:00-05:30, at most 20 images against the
      # 25-per-hour limit. Why: .agents/deploy/hosts/frieren.md §"Agent scheduler".
      image-daily-slot-1 = {
        name = "image-daily-slot-1";
        description = "Image queue 1/4 (01:10, past the UTC reset): due plates, judge, Cloudinary, manifest";
        schedule = "*-*-* 01:10:00";
        command = imageDailySlot "1" 4 0;
        workingDirectory = "${user.home}";
        lockFile = "/tmp/image-daily.lock";
        persistent = false;
        nice = 10;
        ioSchedulingClass = "best-effort";
      };
      image-daily-slot-2 = {
        name = "image-daily-slot-2";
        description = "Image queue 2/4 (07:00): due plates, judge, Cloudinary, manifest";
        schedule = "*-*-* 07:00:00";
        command = imageDailySlot "2" 4 0;
        workingDirectory = "${user.home}";
        lockFile = "/tmp/image-daily.lock";
        persistent = false;
        nice = 10;
        ioSchedulingClass = "best-effort";
      };
      image-daily-slot-3 = {
        name = "image-daily-slot-3";
        description = "Image queue 3/4 (13:20): due plates, judge, Cloudinary, manifest";
        schedule = "*-*-* 13:20:00";
        command = imageDailySlot "3" 4 0;
        workingDirectory = "${user.home}";
        lockFile = "/tmp/image-daily.lock";
        persistent = false;
        nice = 10;
        ioSchedulingClass = "best-effort";
      };
      image-daily-slot-4 = {
        name = "image-daily-slot-4";
        description = "Image queue 4/4 (21:20, end of the day): queue and roster, reserve 10, Cloudinary, manifest";
        schedule = "*-*-* 21:20:00";
        command = imageDailySlot "4" 4 10;
        workingDirectory = "${user.home}";
        lockFile = "/tmp/image-daily.lock";
        persistent = false;
        nice = 10;
        ioSchedulingClass = "best-effort";
      };
    };
  };
}
