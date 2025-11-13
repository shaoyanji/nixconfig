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

    (pkgs.writers.writeBashBin "ytsearch" {}
      /*
      bash
      */
      ''
        case "$1" in "-h" | "--help")
          echo "usage: ytsearch query..."
          exit 0
        esac

        curl -s -G "https://www.youtube.com/results" --data-urlencode "search_query=$*" \
         | tr -d '\n' \
         | sed -e 's#^.*var \+ytInitialData *=##' -e 's#;</script>.*##' \
         | jq -r '..
            | .videoRenderer?
            | select(.)
            | [.title.runs[0].text[:80], (.lengthText.simpleText//"N/A"), (.shortViewCountText.simpleText//"N/A"), (.publishedTimeText.simpleText//"N/A"), .longBylineText.runs[0].text, .videoId]
            | @tsv' \
         | column -s "$(printf '\t')" -t \
         | fzf --with-nth=..-2 \
         | awk '{ print "https://www.youtube.com/watch?v="$NF }'
      '')
  ];
  home.file = {
  };

  home.sessionVariables = {
  };
}
