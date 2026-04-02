{
  config,
  pkgs,
  ...
}: {
  imports = [
    # ./examples.nix
  ];
  home.packages = with pkgs; [
    # Refresh checksums for URL-based config JSON files
    # Usage: nix-hash-update path/to/config.json
    (pkgs.writers.writeBashBin "nix-hash-update" {}
      /*
      bash
      */
      ''
        set -euo pipefail

        if [[ $# -lt 1 ]]; then
          echo "Usage: nix-hash-update <config.json>"
          echo "Updates sha256 checksums for all URLs in the given JSON config"
          exit 1
        fi

        config_file="$1"

        if [[ ! -f "$config_file" ]]; then
          echo "Error: File not found: $config_file"
          exit 1
        fi

        # Normalize URL (ensure https:// prefix)
        normalize_url() {
          local url="$1"
          if [[ "$url" =~ ^https?:// ]]; then
            echo "$url"
          else
            echo "https://$url"
          fi
        }

        # Compute sha256 hash for a URL
        compute_hash() {
          local url="$1"
          curl -sL "$url" | nix-hash --type sha256 --base32 --flat
        }

        # Read the JSON file
        tmp_file=$(mktemp)
        trap "rm -f $tmp_file" EXIT

        # Process each entry and build new JSON
        echo "[" > "$tmp_file"
        first=true

        # Get array length
        len=$(jq 'length' "$config_file")

        for ((i=0; i<len; i++)); do
          url=$(jq -r ".[$i].url" "$config_file")
          url=$(normalize_url "$url")
          hash=$(compute_hash "$url")

          if [[ "$first" == "true" ]]; then
            first=false
          else
            echo "," >> "$tmp_file"
          fi

          jq -n --arg url "$url" --arg sha "sha256:$sha" \
            '{url: $url, sha256: $sha}' >> "$tmp_file"
        done

        echo "]" >> "$tmp_file"

        # Pretty-print and save
        jq '.' "$tmp_file" > "$config_file"

        echo "Updated $len entries in $config_file"
      '')

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
