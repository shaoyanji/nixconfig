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
  # ordering edges). unitConfig and serviceConfig merge over their bases, and a
  # dependency edge both sides name concatenates rather than replaces — a base's
  # `requires` is policy, a site's `after` is topology, and overwriting one
  # drops the other. Every other spec attr passes through to the unit.
  mkDaemon = {
    unitBase ? {},
    serviceBase ? {},
  }: extra: let
    # NixOS' dependency edges, all list-valued: the only attrs where a call site
    # naming the base's key means "add to it" rather than "replace it".
    edgeAttrs = [
      "after"
      "before"
      "bindsTo"
      "conflicts"
      "consistsOf"
      "onFailure"
      "onSuccess"
      "partOf"
      "propagatesReloadTo"
      "reloadTriggers"
      "requisite"
      "requiredBy"
      "requires"
      "upholds"
      "wantedBy"
      "wants"
    ];
    shared =
      builtins.filter
      (k: builtins.isList (unitBase.${k} or null) && builtins.isList (extra.${k} or null))
      edgeAttrs;
  in
    unitBase
    // {
      unitConfig = (unitBase.unitConfig or {}) // (extra.unitConfig or {});
      serviceConfig = serviceBase // (extra.serviceConfig or {});
    }
    // removeAttrs extra (["unitConfig" "serviceConfig"] ++ shared)
    // lib.genAttrs shared (k: extra.${k} ++ unitBase.${k});
}
