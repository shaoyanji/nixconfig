# himalaya mail CLI: account and IMAP wiring; the password is decrypted at runtime.
{
  config,
  user,
  ...
}: {
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
      signature.text = user.shortName;
      himalaya.enable = true;
    };
    "bountystash" = {
      name = "bountystash";
      primary = false;
      address = user.workEmail;
      inherit (user) realName;
      userName = "jisifu";
      imap.host = "imap.gmail.com";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "smtp.gmail.com";
      smtp.port = 465;
      smtp.authentication = "plain";
      passwordCommand = "cat ${config.sops.secrets.gmail.path}";
      signature.text = user.shortName;
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
      signature.text = user.shortName;
      himalaya.enable = true;
    };
  };
  programs.himalaya.enable = true;
}
