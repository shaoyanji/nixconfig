export-env {
  let secrets_map = {
    GITHUB_API_KEY:               "GITHUB.API.KEY"
    POP_FROM:                     "POP.FROM"
    POP_SIGNATURE:                "POP.SIGNATURE"
    POP_SMTP_USERNAME:            "POP.SMTP.USERNAME"
    TODOIST_API_TOKEN:            "TODOIST.API.TOKEN"
    RESEND_API_KEY:               "RESEND.API.KEY"
    SUPERMEMORY_API_KEY:          "SUPERMEMORY.API.KEY"
    NVIDIA_API_KEY:               "NVIDIA.API.KEY"
    GROQ_API_KEY:                 "GROQ.API.KEY"
    OPENROUTER_API_KEY:           "OPENROUTER.API.KEY"
    GEMINI_API_KEY:               "GEMINI.API.KEY"
    COHERE_API_KEY:               "COHERE.API.KEY"
    OPENCODE_API_KEY:             "OPENCODE.API.KEY"
    AIHUBMIX_API_KEY:             "AIHUBMIX.API.KEY"
    BRAVE_API_KEY:                "BRAVE.API.KEY"
    NOTION_API_KEY:               "NOTION.API.KEY"
    PANTRY_API_KEY:               "PANTRY.API.KEY"
    PYTHONANYWHERE_MYSQL_PASSWORD: "PYTHONANYWHERE.MYSQL.PASSWORD"
    PYTHONANYWHERE_API_TOKEN:      "PYTHONANYWHERE.API.TOKEN"
    TWITTER_BEARER_TOKEN:         "TWITTER.BEARER.TOKEN"
    MATAROA_BEARER_TOKEN:         "MATAROA.BEARER.TOKEN"
    IMPROVMX_API_KEY:             "IMPROVMX.API.KEY"
    IMPROVMX_DOMAIN:              "IMPROVMX.DOMAIN"
    NOIP_USERNAMES:               "NOIP.HOSTNAMES"
    NOIP_USERNAME:                "NOIP.USERNAME"
    NOIP_PASSWORD:                "NOIP.PASSWORD"
    CLOUDINARY_API_KEY:           "CLOUDINARY.API.KEY"
    CLOUDINARY_API_SECRET:        "CLOUDINARY.API.SECRET"
    CLOUDINARY_NAME:              "CLOUDINARY.NAME"
  }

  # Helper: extract nested value using a dotted path string
  def get_nested [record, path: string] {
    let parts = ($path | split row ".")
    mut value = $record
    for $part in $parts {
      $value = ($value | get -o $part)
      if $value == null { return null }
    }
    $value
  }

  def apply_yaml_secrets [yaml_record] {
    mut new_env = {}
    for $env_var in ($secrets_map | columns) {
      let dotted = ($secrets_map | get $env_var)
      let value = (get_nested $yaml_record $dotted)
      if $value != null {
        $new_env = ($new_env | merge {($env_var): $value})
      }
    }
    $new_env
  }

  # Helper: true only when a REAL binary is on PATH.
  # `which` alone is fooled by externs declared in completion scripts
  # (e.g. bitwarden-cli-completions.nu declares `bw` with an empty path).
  # We must also verify the resolved path exists on disk.
  def has_bin [name: string] {
    try {
      let found = (which $name | where path != "" | first)
      if $found == null { return false }
      ($found.path | path exists)
    } catch { false }
  }

  let sops_path  = $"($env.HOME)/nixconfig/modules/secrets/apikeys.yaml"
  let nas_key    = "/Volumes/data/security/secrets/key.txt"
  let nas_env    = "/Volumes/data/security/secrets/.env.age"

  # Branch 1: local sops file (primary — requires initialized secrets submodule)
  if (($sops_path | path exists) and (has_bin sops)) {
    try {
      let yaml = (sops -d $sops_path | from yaml)
      load-env (apply_yaml_secrets $yaml)
    } catch { |err|
      print -e $"(ansi yellow)secrets.nu: sops decrypt of ($sops_path) failed — check your age key \(~/.config/sops/age/keys.txt\): ($err.msg)(ansi reset)"
    }
  } else if (($nas_key | path exists) and ($nas_env | path exists) and (has_bin age)) {
    # Branch 2: age-encrypted flat .env from NAS mount
    try {
      let age_secrets = {
        GROQ_API_KEY:          "GROQ"
        GITHUB_API_KEY:        "GITHUB"
        GEMINI_API_KEY:        "GEMINI"
        COHERE_API_KEY:        "COHERE"
        MATAROA_BEARER_TOKEN:  "MATAROA"
      }
      let lines = (age -d -i $nas_key $nas_env | str trim | lines)
      mut new_env = {}
      for $env_var in ($age_secrets | columns) {
        let prefix = ($age_secrets | get $env_var)
        let matched = ($lines | where {|line| $line | str starts-with $"($prefix)="})
        if ($matched | is-not-empty) {
          $new_env = ($new_env | merge {($env_var): ($matched | get 0 | split row "=" | get 1)})
        }
      }
      load-env $new_env
    } catch { |err|
      print -e $"(ansi yellow)secrets.nu: NAS age decrypt failed: ($err.msg)(ansi reset)"
    }
  } else if (has_bin bw) {
    # Branch 3: Bitwarden (only when the real CLI binary is installed)
    try {
      let status = (bw status | from json)
      if $status.status != "unlocked" {
        let output = (bw unlock | str trim)
        let session_line = ($output | lines | find "export BW_SESSION" | get -o 0)
        if $session_line != null {
          $env.BW_SESSION = ($session_line | split row '"' | get 1)
        } else {
          error make {msg: "Could not extract BW_SESSION from bw unlock"}
        }
      }
      mut new_env = {}
      for $env_var in ($secrets_map | columns) {
        let item = (bw get item $env_var | complete)
        if $item.exit_code == 0 {
          let value = ($item.stdout | from json | get -o notes)
          if $value != null {
            $new_env = ($new_env | merge {($env_var): $value})
          }
        }
      }
      load-env $new_env
    } catch { |err|
      print -e $"(ansi yellow)secrets.nu: bitwarden branch failed: ($err.msg)(ansi reset)"
    }
  } else if (has_bin sops) {
    # Branch 4: remote fallback
    try {
      let remote_yaml = (http get https://github.com/shaoyanji/secrets/raw/refs/heads/master/apikeys.yaml)
      let yaml = (sops -d $remote_yaml | from yaml)
      load-env (apply_yaml_secrets $yaml)
    } catch { |err|
      print -e $"(ansi yellow)secrets.nu: remote fallback failed: ($err.msg)(ansi reset)"
    }
  } else {
    print -e $"(ansi yellow)secrets.nu: no secrets source available \(missing submodule? run: git submodule update --init\)(ansi reset)"
  }
}
