# lib/systemd-jobs.nix — the fleet's two unit skeletons as pure functions.
# A daemon is a restartable service under a crash-loop class; a timer job is a
# Type=oneshot service driven by a timers.target/Persistent timer. Each call
# site names its base attrs (class, ordering, sandbox) and the spec names only
# what differs, so the skeleton lives here and the policy stays visible at the
# site. systemd-policy.nix classifies the evaluated result, so the helper's
# location changes nothing the gate sees.
{lib}: {
  # serviceBase: the site's shared serviceConfig tail (type, user, sandbox).
  # spec: description, timerDescription, onCalendar and the per-job extras;
  # `enable` carries a conditional (a filtered-out job and a `mkIf false`
  # definition produce the same option value), serviceConfig merges over the
  # base, everything else passes through to the service. A null
  # timerDescription emits no Description on the timer at all.
  mkTimerJob = serviceBase: {
    description,
    timerDescription ? null,
    onCalendar,
    randomizedDelaySec ? null,
    enable ? true,
    serviceConfig ? {},
    ...
  } @ spec: {
    inherit enable;
    service =
      removeAttrs spec [
        "description"
        "timerDescription"
        "onCalendar"
        "randomizedDelaySec"
        "enable"
        "serviceConfig"
      ]
      // {
        inherit description;
        serviceConfig = serviceBase // serviceConfig;
      };
    timer =
      {
        wantedBy = ["timers.target"];
        timerConfig =
          {
            OnCalendar = onCalendar;
            Persistent = true;
          }
          // lib.optionalAttrs (randomizedDelaySec != null) {
            RandomizedDelaySec = randomizedDelaySec;
          };
      }
      // lib.optionalAttrs (timerDescription != null) {description = timerDescription;};
  };

  # unitBase: the site's shared unit attrs (wantedBy, unitConfig class marker,
  # ordering edges). unitConfig and serviceConfig merge over their bases;
  # every other spec attr passes through to the unit.
  mkDaemon = {
    unitBase ? {},
    serviceBase ? {},
  }: extra:
    unitBase
    // {
      unitConfig = (unitBase.unitConfig or {}) // (extra.unitConfig or {});
      serviceConfig = serviceBase // (extra.serviceConfig or {});
    }
    // removeAttrs extra ["unitConfig" "serviceConfig"];
}
