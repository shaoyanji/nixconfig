# lib/systemd-policy.nix — systemd unit classification as pure functions, so the
# gate runs over the evaluated unit set and each rule can be exercised against
# synthetic units (see modules/systemd-policy.nix, docs/nix-patterns.md).
{lib}: let
  # systemd defaults: five starts inside ten seconds, then the unit is retired
  # until something starts it by hand.
  windowMs = 10000;
  burst = 5;

  # systemd's restart delay when `RestartSec` is unset.
  defaultDelayMs = 100;

  # "10s" | "500ms" | "2min" | 10 | null -> milliseconds.
  delayMs = v:
    if v == null
    then defaultDelayMs
    else if builtins.isInt v
    then v * 1000
    else if lib.isString v
    then let
      m = v |> builtins.match "([0-9]+)(ms|s|min)?";
    in
      if m == null
      then defaultDelayMs
      else let
        n = m |> builtins.head |> lib.toInt;
        unit = builtins.elemAt m 1;
      in
        if unit == "ms"
        then n
        else if unit == "min"
        then n * 60000
        else n * 1000
    else defaultDelayMs;

  # Both spellings are in this tree: home-manager's raw `Service`/`Unit` sections
  # and the `serviceConfig`/`unitConfig` convenience options.
  serviceSection = u: u.Service or u.serviceConfig or {};
  unitSection = u: u.Unit or u.unitConfig or {};
  installSection = u: u.Install or u.install or {};
  listOf = set: key: set.${key} or [];

  startLimitOf = u: (unitSection u).StartLimitIntervalSec or null;
  restartOf = u: (serviceSection u).Restart or null;
  restartDelayOf = u: delayMs ((serviceSection u).RestartSec or null);

  # systemd disables the limiter with `StartLimitIntervalSec = 0`.
  unlimited = u: let
    v = startLimitOf u;
  in
    v == 0 || v == "0";

  # A crash loop can retire the unit: restarts are fast enough to fit `burst`
  # starts inside the window and nothing turned the limiter off.
  retirable = u:
    restartOf u
    != null
    && restartOf u
    != "no"
    && !(unlimited u)
    && restartDelayOf u
    * burst
    < windowMs;

  # The unit expects a running compositor. Existence is a different question: a
  # unit can be gated correctly by `mkIf` and never appear at all.
  sessionBound = u:
    (
      ["graphical-session.target" "graphical-session-pre.target"]
      |> lib.any (t: (listOf (installSection u) "WantedBy" ++ listOf (installSection u) "RequiredBy") |> builtins.elem t)
    )
    || (
      ["graphical-session.target" "graphical-session-pre.target"]
      |> lib.any (t: (listOf (unitSection u) "PartOf" ++ listOf (unitSection u) "Wants" ++ listOf (unitSection u) "Requires") |> builtins.elem t)
    );

  # Something starts the unit: a target via Install, another unit via
  # PartOf/Wants/Requires, or a timer. A oneshot nobody triggers is dead config.
  reachable = timers: name: u: let
    install = installSection u;
    unit = unitSection u;
    named = i: timers.${i}.Timer.Unit or null == "${name}.service";
    timerActivates = (timers |> builtins.hasAttr name) || (timers |> builtins.attrNames |> lib.any named);
  in
    listOf install "WantedBy"
    != []
    || listOf install "RequiredBy"
    != []
    || listOf unit "PartOf"
    != []
    || listOf unit "Wants"
    != []
    || listOf unit "Requires"
    != []
    || timerActivates;

  # One message per violation, phrased as the fix rather than the symptom.
  userUnitViolations = {
    services,
    timers,
    sessionDeclared,
  }: let
    names = services |> builtins.attrNames;
    retirableNames = names |> builtins.filter (n: services.${n} |> retirable);
    sessionNames = names |> builtins.filter (n: services.${n} |> sessionBound);
    orphanNames = names |> builtins.filter (n: !(services.${n} |> reachable timers n));
  in
    lib.optionals (!sessionDeclared) (
      sessionNames |> map (n: "user unit '${n}' is bound to graphical-session.target but this generation declares no compositor — gate its existence on the session capability (programs.niri.enable) instead of enabling it everywhere")
    )
    ++ (retirableNames |> map (n: "user unit '${n}' can be retired by systemd's start limit (Restart=${services.${n} |> restartOf |> toString}, RestartSec=${services.${n} |> restartDelayOf |> toString}ms, StartLimitIntervalSec unset) — set StartLimitIntervalSec=0 with RestartSteps/RestartMaxDelaySec, or a RestartSec that cannot fit ${burst |> toString} starts in ${windowMs |> toString}ms"))
    ++ (orphanNames |> map (n: "user service '${n}' is started by nothing: no Install.WantedBy/RequiredBy, no PartOf/Wants/Requires, no timer — delete it or give it an entry point"));

  # A system unit this repo declares states its own class at the point of
  # declaration, so there is no registry to drift:
  #   "daemon"  must come back — Restart set, and never retirable.
  #   "bounded" means retiring is the point — it must say so with an explicit
  #             StartLimitBurst instead of inheriting systemd's default.
  fleetRole = u: (unitSection u).X-Fleet-Role or null;

  markedSystemViolations = {services}: let
    names = services |> builtins.attrNames;
    role = n: services.${n} |> fleetRole;
    marked = names |> builtins.filter (n: role n != null);
    unknown = marked |> builtins.filter (n: !(["daemon" "bounded"] |> builtins.elem (role n)));
    daemons = marked |> builtins.filter (n: role n == "daemon");
    bounded = marked |> builtins.filter (n: role n == "bounded");
  in
    (unknown
      |> map (n: "system unit '${n}' has X-Fleet-Role=${role n |> toString}, which is not \"daemon\" or \"bounded\""))
    ++ (daemons |> builtins.filter (n: (services.${n} |> restartOf) == null || (services.${n} |> restartOf) == "no") |> map (n: "system unit '${n}' is classified a daemon but sets no Restart= — nothing brings it back after a crash"))
    ++ (daemons |> builtins.filter (n: services.${n} |> retirable) |> map (n: "system unit '${n}' is classified a daemon and can be retired by systemd's start limit (Restart=${services.${n} |> restartOf |> toString}, RestartSec=${services.${n} |> restartDelayOf |> toString}ms, StartLimitIntervalSec unset) — set StartLimitIntervalSec=0 with RestartSteps/RestartMaxDelaySec, or reclassify it \"bounded\" with an explicit StartLimitBurst"))
    ++ (bounded |> builtins.filter (n: !(services.${n} |> unitSection |> builtins.hasAttr "StartLimitBurst")) |> map (n: "system unit '${n}' is classified \"bounded\" without an explicit StartLimitBurst — inheriting the default is not a decision"));
in {
  inherit
    retirable
    sessionBound
    reachable
    delayMs
    fleetRole
    userUnitViolations
    markedSystemViolations
    ;
}
