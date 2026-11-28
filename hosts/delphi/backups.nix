# docs/email-archive.md#backup
{self, ...}: {
  imports = [self.modules."services.postgres-backup-drill"];

  services.postgresqlBackup = {
    enable = true;
    databases = ["email_archive" "umami" "miniflux"];
    location = "/var/backup/postgresql";
    startAt = "*-*-* 02:50:00";
  };

  services.offloadBridge.sets.delphi-postgres.path = "/var/backup/postgresql";

  # 241 messages carry a 25 MB tree; Drive, the copy it was promised, never ran.
  services.offloadBridge.sets.email-attachments.path = "/var/lib/npgsqlrest/attachments";

  services.postgresBackupDrill = {
    enable = true;
    backupDir = "/var/backup/postgresql";
    databases = ["email_archive" "umami" "miniflux"];
    assertMinimumTables = 14;
    schedule = "Sun *-*-* 05:00:00";
  };
}
