# The email archive on delphi: NpgsqlRest on loopback, tailnet-only through the
# `tailscale serve` mount in the portal registry. docs/email-archive.md.
{...}: {
  imports = [
    ../../modules/services/email-archive.nix
    # A guest plugin: it declares its own tables, endpoints and routing through
    # services.emailArchive.plugins. modules/plugins/appflow/README.md.
    ../../modules/plugins/appflow
  ];

  services.emailArchive = {
    enable = true;
    # The timer runs from the first boot; the sync unit is skipped until the
    # operator writes the rclone remote (docs/email-archive.md). Same rule as the
    # calendar's token: `ConditionPathExists` on state, never a sops key.
    gdrive.enable = true;
    # The importer walks the live inbox every hour and hands each new message to
    # the endpoint; 200 new messages a run is a backfill pace, not a limit on the
    # archive (successive runs continue where the previous one stopped).
    importer = {
      enable = true;
      limit = 200;
    };
    # Triage runs after the import. The VIP list is sops
    # (`email-archive.vip-senders`); a new classifier name re-judges the archive,
    # and the newest verdict per message is the one every read uses.
    triage = {
      enable = true;
      # Bumped because the routing changed: a new name re-judges the archive, and
      # the newest verdict per message is the one every read uses.
      classifier = "rules+engine+apps+pointer";
      # Same reason on the second opinion: the pass may now override in both
      # directions and closes a repeat sender, so every row is re-read under it.
      secondClassifier = "second-pass+feed";
      # The Gumloop assistant writes one daily digest. It is an agent pointing at
      # what it thinks matters — regular, not bulk — so it stays in front of a
      # person and the feed rule may not close it.
      pointers = ["gumball@gumloop.ai"];
    };
  };

  # No `import.source`: the pipeline is imported on demand while the workflow's
  # JSON is still where new applications appear. Once the database is the source,
  # this stays empty and the timer never exists.
  services.appflowPlugin.enable = true;
}
