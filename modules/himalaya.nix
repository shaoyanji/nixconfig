# himalaya mail CLI: account and IMAP wiring; the password is decrypted at runtime.
{config, ...}: let
  user = import ./global/user.nix;
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
  };
  programs.himalaya.enable = true;
}
