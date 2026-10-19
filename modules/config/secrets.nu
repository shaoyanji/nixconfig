# modules/config/secrets.nu
# Sane, high-performance secrets loader for Nushell.
#
# Design invariants:
# 1. Zero shell-startup lag: Caches decrypted secrets in user tmpfs RAM (/run/user/<uid>/nushell-secrets.json).
#    Subsequent shell opens load secrets in ~200 µs without spawning sops or hitting TPM/disk.
# 2. Hardware-aware: Detects TPM 2.0 identity (tpm-identity.txt) vs software key (keys.txt).
# 3. Dynamic path resolution: Finds apikeys.yaml across standard repo locations ($env.HOME/Documents/nixconfig, etc.).
# 4. Fallback to sops-nix in-memory secrets (~/.config/sops-nix/secrets/) if apikeys.yaml is absent.
# 5. Zero network requests on shell launch. No blocking Bitwarden calls on startup.
# 6. Provides an interactive `reload-secrets` command to invalidate cache on demand.

def --env reload-secrets [] {
  let runtime_dir = ($env.XDG_RUNTIME_DIR? | default $"/run/user/(id -u)")
  let cache_file = $"($runtime_dir)/nushell-secrets.json"
  if ($cache_file | path exists) {
    try { rm -f $cache_file }
  }
  _load_all_secrets true
}

def --env _load_all_secrets [force_refresh: bool = false] {
  # 1. Ensure SOPS_AGE_KEY_FILE is set in environment if not already present
  if ($env.SOPS_AGE_KEY_FILE? == null or $env.SOPS_AGE_KEY_FILE == "") {
    let candidate_keys = [
      $"($env.HOME)/.config/sops/age/tpm-identity.txt",
      $"($env.HOME)/.config/sops/age/keys.txt",
    ]
    let key_file = ($candidate_keys | where {|k| $k | path exists} | get -o 0)
    if $key_file != null {
      load-env { SOPS_AGE_KEY_FILE: $key_file }
    }
  }

  # 2. Skip only if THIS loader already ran in this process. Keying the check
  # off one variable (GEMINI_API_KEY) was wrong: a session can export some keys
  # without the rest, and the cache was then never read, so the missing keys
  # stayed missing no matter how often the shell restarted.
  if (not $force_refresh) and ($env.NU_SECRETS_LOADED? == "1") {
    return
  }

  let runtime_dir = ($env.XDG_RUNTIME_DIR? | default $"/run/user/(id -u)")
  let cache_file = $"($runtime_dir)/nushell-secrets.json"

  # 3. Candidate repo locations for apikeys.yaml
  let candidate_paths = [
    ($env.SOPS_APIKEYS_PATH? | default ""),
    $"($env.HOME)/Documents/nixconfig/modules/secrets/apikeys.yaml",
    $"($env.HOME)/nixconfig/modules/secrets/apikeys.yaml",
    "/Volumes/data/projects/nixconfig/modules/secrets/apikeys.yaml",
    "/srv/data/projects/nixconfig/modules/secrets/apikeys.yaml",
  ]
  let sops_path = ($candidate_paths | where {|p| ($p != "") and ($p | path exists)} | get -o 0)

  # 4. Fast-path: Check if RAM cache exists and is fresh
  if (not $force_refresh) and ($cache_file | path exists) {
    let cache_fresh = if ($sops_path != null) {
      try {
        let cache_mtime = (ls -D $cache_file | get 0.modified)
        let sops_mtime = (ls -D $sops_path | get 0.modified)
        ($cache_mtime > $sops_mtime)
      } catch { true }
    } else {
      true
    }

    if $cache_fresh {
      try {
        let secrets = (open $cache_file)
        load-env $secrets
        load-env {NU_SECRETS_LOADED: "1"}
        return
      } catch {
        # Corrupt cache, fall through to regenerate
      }
    }
  }

  # 5. Extract secrets from apikeys.yaml if available and sops is installed
  let has_sops = try {
    let found = (which sops | where path != "" | first)
    if $found == null { false } else { ($found.path | path exists) }
  } catch { false }

  mut collected = {}

  if ($sops_path != null and $has_sops) {
    let secrets_map = {
      GITHUB_API_KEY:                "GITHUB.API.KEY"
      POP_FROM:                      "POP.FROM"
      POP_SIGNATURE:                 "POP.SIGNATURE"
      POP_SMTP_USERNAME:             "POP.SMTP.USERNAME"
      TODOIST_API_TOKEN:             "TODOIST.API.TOKEN"
      RESEND_API_KEY:                "RESEND.API.KEY"
      SUPERMEMORY_API_KEY:           "SUPERMEMORY.API.KEY"
      NVIDIA_API_KEY:                "NVIDIA.API.KEY"
      GROQ_API_KEY:                  "GROQ.API.KEY"
      OPENROUTER_API_KEY:            "OPENROUTER.API.KEY"
      GEMINI_API_KEY:                "GEMINI.API.KEY"
      COHERE_API_KEY:                "COHERE.API.KEY"
      OPENCODE_API_KEY:              "OPENCODE.API.KEY"
      AIHUBMIX_API_KEY:              "AIHUBMIX.API.KEY"
      BRAVE_API_KEY:                 "BRAVE.API.KEY"
      NOTION_API_KEY:                "NOTION.API.KEY"
      PANTRY_API_KEY:                "PANTRY.API.KEY"
      PYTHONANYWHERE_MYSQL_PASSWORD: "PYTHONANYWHERE.MYSQL.PASSWORD"
      PYTHONANYWHERE_API_TOKEN:      "PYTHONANYWHERE.API.TOKEN"
      TWITTER_BEARER_TOKEN:          "TWITTER.BEARER.TOKEN"
      MATAROA_BEARER_TOKEN:          "MATAROA.BEARER.TOKEN"
      IMPROVMX_API_KEY:              "IMPROVMX.API.KEY"
      IMPROVMX_DOMAIN:               "IMPROVMX.DOMAIN"
      NOIP_USERNAMES:                "NOIP.HOSTNAMES"
      NOIP_USERNAME:                 "NOIP.USERNAME"
      NOIP_PASSWORD:                 "NOIP.PASSWORD"
      CLOUDINARY_API_KEY:            "CLOUDINARY.API.KEY"
      CLOUDINARY_API_SECRET:         "CLOUDINARY.API.SECRET"
      CLOUDINARY_NAME:               "CLOUDINARY.NAME"
      TYPESAFE_API_KEY:              "TYPESAFE.API.KEY"
    }

    def _get_nested [record, path: string] {
      let parts = ($path | split row ".")
      mut val = $record
      for $part in $parts {
        $val = ($val | get -o $part)
        if $val == null { return null }
      }
      $val
    }

    try {
      let yaml = (sops -d $sops_path | from yaml)
      for $k in ($secrets_map | columns) {
        let dotted = ($secrets_map | get $k)
        let v = (_get_nested $yaml $dotted)
        if $v != null {
          $collected = ($collected | merge {($k): $v})
        }
      }
    } catch { |err|
      if ($env.DEBUG_SECRETS? == "1") {
        print -e $"(ansi yellow)secrets.nu: sops decrypt failed: ($err.msg)(ansi reset)"
      }
    }
  }

  # 6. Fallback/Augment from sops-nix in-memory secrets (~/.config/sops-nix/secrets)
  let sops_nix_dir = $"($env.HOME)/.config/sops-nix/secrets"
  if ($sops_nix_dir | path exists) {
    let sops_nix_map = {
      GEMINI_API_KEY: $"($sops_nix_dir)/gemini/api/key",
      OPENMETEO_API_KEY: $"($sops_nix_dir)/openmeteo/api/key",
      GITHUB_API_KEY: $"($sops_nix_dir)/ghsudo",
      NEOCITIES_API_KEY: $"($sops_nix_dir)/neocities",
      AWS_ACCESS_KEY_ID: $"($sops_nix_dir)/aws/access/key/id",
      AWS_SECRET_ACCESS_KEY: $"($sops_nix_dir)/aws/secret/access/key",
    }
    for $k in ($sops_nix_map | columns) {
      if ($collected | get -o $k) == null {
        let path = ($sops_nix_map | get $k)
        if ($path | path exists) {
          try {
            let secret_val = (open $path | str trim)
            if ($secret_val != "") {
              $collected = ($collected | merge {($k): $secret_val})
            }
          } catch {}
        }
      }
    }
  }

  # 7. If any secrets were collected, write to tmpfs cache and load
  if ($collected | is-not-empty) {
    # Create the cache 0600 from the start. `save` creates 0644 under the
    # default umask, so the old chmod-after-save left a window where the file
    # was readable by anyone who could traverse /run/user/<uid>. Creating it
    # first with `install` and letting `save -f` truncate preserves the mode.
    try {
      ^install -m 600 /dev/null $cache_file
      $collected | to json | save -f $cache_file
    } catch {}
    load-env $collected
    load-env {NU_SECRETS_LOADED: "1"}
  }
}

export-env {
  _load_all_secrets false
}
