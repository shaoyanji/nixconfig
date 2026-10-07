{ config, ... }: {
  accounts.email.accounts = {
    "jisifu" = {
      name = "jisifu";
      primary = true;
      address = "jisifu@gmail.com";
      realName = "Shao-yan (Matt) Ji";
      userName = "jisifu";
      imap.host = "imap.gmail.com";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "smtp.gmail.com";
      smtp.port = 465;
      smtp.authentication = "plain";
      # passwordCommand = "nu -c '( bw list items --session $env.BW_SESSION --url https://google.com | from json | get fields.0.0.value)'";
      passwordCommand = "cat ${config.sops.secrets.gmail.path}";
      signature.text = "Matt Ji";
      himalaya.enable = true;
    };
    "bountystash" = {
      name = "bountystash";
      primary = false;
      address = "matt@bountystash.com";
      realName = "Shao-yan (Matt) Ji";
      userName = "jisifu";
      imap.host = "imap.gmail.com";
      imap.port = 993;
      imap.authentication = "plain";
      smtp.host = "smtp.gmail.com";
      smtp.port = 465;
      smtp.authentication = "plain";
      passwordCommand = "cat ${config.sops.secrets.gmail.path}";
      signature.text = "Matt Ji";
      himalaya.enable = true;
    };
  };
  programs.himalaya.enable = true;
}
