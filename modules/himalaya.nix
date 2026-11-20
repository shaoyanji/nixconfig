# himalaya mail CLI: account and IMAP wiring; the password is decrypted at runtime.
{
  self,
  config,
  user,
  ...
}: let
  # One renderer for the mail signature: this reads the profile TOML at eval
  # time, so what himalaya appends and `task gravatar:signature` prints cannot
  # disagree. Named, not pathed, so `checks:modules:edges` can follow it.
  gravatar = import self.modules."config.gravatar-profile";
in {
  accounts.email.accounts = {
    "jisifu" = {
      name = "jisifu";
      primary = true;
      address = user.email;
      inherit (user) realName;
      userName = "jisifu";
      imap.host = "imap.gmail.com";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "smtp.gmail.com";
      smtp.port = 465;
      smtp.authentication = "plain";
      passwordCommand = "cat ${config.sops.secrets.gmail.path}";
      # `Sent`, `Drafts` and `Trash` are stale Gmail labels, not the mailboxes.
      # himalaya 2.2.1 reads `mailbox.alias`; it ignores `folder.aliases`.
      folders.sent = "[Gmail]/Sent Mail";
      folders.drafts = "[Gmail]/Drafts";
      folders.trash = "[Gmail]/Trash";
      himalaya.settings.mailbox.alias.sent = "[Gmail]/Sent Mail";
      himalaya.settings.mailbox.alias.drafts = "[Gmail]/Drafts";
      himalaya.settings.mailbox.alias.trash = "[Gmail]/Trash";
      signature.text = gravatar.signature;
      himalaya.enable = true;
    };
    "bountystash" = {
      name = "bountystash";
      primary = false;
      address = user.workEmail;
      inherit (user) realName;
      # Reading stays on the Gmail box; only sending moves. A personal Gmail
      # alias signs d=gmail.com and never aligns for DMARC, so SMTP goes through
      # Resend, whose relay signs bountystash.com: login `resend`, password the
      # Resend key. One passwordCommand per account is why sasl is overridden
      # here.
      userName = "jisifu";
      imap.host = "imap.gmail.com";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "smtp.resend.com";
      smtp.port = 465;
      smtp.authentication = "plain";
      passwordCommand = "cat ${config.sops.secrets.gmail.path}";
      himalaya.settings.smtp.sasl.plain = {
        username = "resend";
        password.command = "cat ${config.sops.secrets.resend-api-key.path}";
      };
      # As `jisifu`: same Sent, Drafts and Trash folders, same alias keys.
      folders.sent = "[Gmail]/Sent Mail";
      folders.drafts = "[Gmail]/Drafts";
      folders.trash = "[Gmail]/Trash";
      himalaya.settings.mailbox.alias.sent = "[Gmail]/Sent Mail";
      himalaya.settings.mailbox.alias.drafts = "[Gmail]/Drafts";
      himalaya.settings.mailbox.alias.trash = "[Gmail]/Trash";
      signature.text = gravatar.signature;
      himalaya.enable = true;
    };
    # envs.net pubnix mail: implicit TLS 993, submission 587 needs STARTTLS;
    # the login is the full address (the unix name `jisifu` does not authenticate).
    "envs" = {
      name = "envs";
      primary = false;
      address = user.envsEmail;
      inherit (user) realName;
      userName = user.envsEmail;
      imap.host = "mail.envs.net";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "mail.envs.net";
      smtp.port = 587;
      smtp.authentication = "plain";
      smtp.tls.useStartTls = true;
      passwordCommand = "cat ${config.sops.secrets.envsmail.path}";
      signature.text = gravatar.signature;
      himalaya.enable = true;
    };
    # Alwaysdata Dragon Court mailbox: implicit TLS 993, SMTPS 465; login is the address.
    "dragoncourt" = {
      name = "dragoncourt";
      primary = false;
      address = user.alwaysdataEmail;
      inherit (user) realName;
      userName = user.alwaysdataEmail;
      imap.host = "imap-dragoncourt.alwaysdata.net";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "smtp-dragoncourt.alwaysdata.net";
      smtp.port = 465;
      smtp.authentication = "plain";
      passwordCommand = "cat ${config.sops.secrets.alwaysdataemail.path}";
      signature.text = gravatar.signature;
      himalaya.enable = true;
    };
  };
  programs.himalaya.enable = true;
}
