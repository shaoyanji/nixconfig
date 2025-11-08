{
  config,
  pkgs,
  ...
}: {
  imports = [
    # ./examples.nix
  ];
  home.packages = with pkgs; [
    (pkgs.writers.writeBashBin "nixhash.sh" {}
      /*
      bash
      */
      ''
        normalize_url() {
        	local url=$(cat)
        	if [[ "$url" =~ ^https?:// ]]; then
        		echo "$url"
        	else
        		echo "https://$url"
        	fi
        }

        nix-hash --type sha256 --base32 --flat <(curl -so - $(cat))
      '')
  ];
  home.file = {
  };

  home.sessionVariables = {
  };
}
