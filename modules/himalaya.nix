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
      signature.text = gravatar.signature;
      himalaya.enable = true;
    };
    "bountystash" = {
      name = "bountystash";
      primary = false;
      address = user.workEmail;
      inherit (user) realName;
      # Reading stays on the Gmail mailbox that holds the mail; only sending
      # moves. A personal Gmail account signs an alias with d=gmail.com, so mail
      # from this address never aligned for DMARC. Resend holds the domain's
      # DKIM key (resend._domainkey.bountystash.com), and its relay signs as
      # bountystash.com, so the account's SMTP password is the Resend key and
      # the login is the literal `resend`. The Home Manager module takes one
      # passwordCommand per account, hence the per-account smtp sasl override.
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
      signature.text = gravatar.signature;
      himalaya.enable = true;
    };
    # envs.net pubnix mail. Implicit TLS on 993, submission on 587 needs STARTTLS
    # spelled out; the login is the full address, which is what the server
    # accepts (the unix name `jisifu` alone does not authenticate).
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
    # Alwaysdata hosting mailbox for Dragon Court. Implicit TLS on 993,
    # SMTPS on 465; the login is the full address.
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
