# =============================================================================
# utils.nu - Personal NuShell utility commands
# Category: General helpers, API clients, system integration
# =============================================================================

# Configuration constants for hardcoded paths and defaults
const CONFIG = {
  volumes: {
    data: "/Volumes/data"
    appimages: "/Volumes/data/appimages"
    audiobooks: "/Volumes/data/audiobooks"
    arr: "/Volumes/data/arr"
  }
  network: {
    microvm_ip: "192.168.83.10"
    microvm_bridge: "brlan"
  }
  gist: {
    movie_list_id: "f54acf4ff3274a96d3287003e7cdc988"
  }
}

# =============================================================================
# Section: Network & API
# =============================================================================

# Fetches and displays current xkcd comic in kitty terminal
# Example: xkcd
export def xkcd [] {
  load-env {TERM: "kitty"}
  let comic = (http get https://xkcd.com/info.0.json | from json | get img)
  http get $comic | viu -
}

# Interactive anime image search via Nekosia API
# Selects a random tag, fetches image, and displays in kitty
# Example: animepic
export def animepic [] {
  load-env {TERM: "kitty"}
  let tags = "random, catgirl, foxgirl, wolf-girl, animal-ears, tail, tail-with-ribbon, tail-from-under-skirt, cute, cuteness-is-justice, blue-archive, girl, young-girl, maid, maid-uniform, vtuber, w-sitting, lying-down, hands-forming-a-heart, wink, valentine, headphones, thigh-high-socks, knee-high-socks, white-tights, black-tights, heterochromia, uniform, sailor-uniform, hoodie, ribbon, white-hair, blue-hair, long-hair, blonde, blue-eyes, purple-eyes"
  let selected_tag = ($tags | split row ", " | input list -f)
  let api_url = $"https://api.nekosia.cat/api/v1/images/($selected_tag)"
  let image_url = (http get $api_url | from json | get image.compressed.url)
  http get $image_url | viu -
}

# Fetches current weather from wttr.in as JSON (or terminal text)
# Example: weather
# Example: weather "Berlin"
export def weather [location: string = ""] {
  if ($location | is-empty) {
    http get "https://wttr.in/?format=j1"
  } else {
    http get $"https://wttr.in/($location)?format=j1"
  }
}

# Searches public APIs from public-api-lists repository
# Returns selected API details via fzf picker
# Example: publicapi
export def "publicapi" [] {
  let url = "https://raw.githubusercontent.com/public-api-lists/public-api-lists/refs/heads/master/README.md"
  let data = (http get $url | mdq ':-: /API|Description|Auth|HTTPS|CORS/ :-:' -l inline -o json | from json | get items.table.rows | flatten | uniq)
  let selected = ($data | sk --preview {} --format {get 1} | get 0)
  $selected
}

# Uses ddgr to return abstract for a search term
# Example: "some search query" | util ddgr
export def "util ddgr" [] {
  let query = $in | ddgr -n 1 --json --noua | from json | first | get abstract
  $query
}

# Prompts for search term and returns URL via fuzzy picker
# Example: browse
export def browse [] {
  let search_term = (input 'Search> ')
  let results = (ddgr -n 25 --json $search_term | from json | input list -f -d title | get url)
  $results
}

# Returns markdown from a URL
# Example: browse | browsemd
export def "browsemd" [] {
  let url = $in
  let html = (http get $url | htmlq body -w -r script | html2markdown)
  glow $html
}

# Returns hyperlink from a URL
# Example: "https://example.com" | browse link
export def "browse link" [] {
  let url = $in
  let links = (http get $url | htmlq -w -a href a | split row "\n" | input list -f)
  $links
}

# Scrapes markdown links from a URL
# Example: "https://example.com" | scrape md
export def "scrape md" [] {
  let url = $in
  let data = (http get $url | mdq '#' -o json -l inline | from json | get items.0 | flatten | flatten | flatten | flatten | flatten | flatten | flatten | flatten | flatten | flatten | flatten | input list -f | get paragraph | mdq '[]()' -o json -l inline | from json | get items.link.url.0)
  $data
}

# Returns markdown link from a markdown file URL
# Example: "https://example.com/README.md" | browse mdlink
export def "browse mdlink" [] {
  let url = $in
  let data = (http get $url | mdq '-' -o json -l inline | from json | get items.list | flatten | get item | flatten | get paragraph | input list -f | parse "{md} {description}" | get md | mdq '[]()' -o json | from json | get items.link.url.0)
  $data
}

# Returns HTML body from a URL
# Example: "https://example.com" | browse html
export def "browse html" [] {
  let url = $in
  http get $url | htmlq body -w
}

# Searches and plays video via ytsearch (from gist.nu)
# Example: ytfzf
export def ytfzf [] {
  mpv --ytdl-format="bv+ba" (ytsearch (input))
}

# deprecated -- TODO: FIX
# # Rewritten YouTube search - parses search results page
# # Example: nuytsearch
# export def nuytsearch [] {
#   let query = (input | url encode)
#   let results_url = $"https://www.youtube.com/results?search_query=($query)"
#   let html = (http get $results_url)
#   let json_str = ($html | split row "var ytInitialData =" | last | split row ";</script>" | first | from json)
#   let videos = ($json_str | get -o contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents.0.itemSectionRenderer.contents.videoRenderer)
#   let choices = ($videos | uniq | sort | drop | select title.runs.text.0 videoId | flatten)
#   let selected = ($choices | input list -f -d "title.runs.text.0" | get videoId)
#   $"https://www.youtube.com/watch?v=($selected)"
# }

# Searches Nixpkgs via Jetify Nixhub API
# Uses the /v2/search endpoint with q query parameter
# Example: nixpkgs hello
# Example: nixpkgs ffmpeg
export def nixpkgs [query: string] {
  let url = $"https://search.devbox.sh/v2/search?q=($query)"
  let json = (curl -s $url)
  let results = ($json | from json)
  let packages = ($results | get results | each {|p| {name: $p.name, summary: $p.summary}})
  if ($packages | is-empty) {
    print "No packages found"
  } else {
    $packages
  }
}

# Simple paste bin using envs.sh
# Example: "hello world" | 0file
export def "0file" [] {
  let content = $in
  let response = (http post --content-type multipart/form-data https://envs.sh { file: ($content | into binary) })
  print $response
}

# Proxy through improvmx API - adds email alias
# Requires: IMPROVMX_API_KEY, IMPROVMX_DOMAIN env vars
# Example: improvmx add
export def "improvmx add" [] {
  if $env.IMPROVMX_API_KEY == null {
    error make {msg: "Environment variable IMPROVMX_API_KEY is required", label: "IMPROVMX_API_KEY not set"}
  }
  if $env.IMPROVMX_DOMAIN == null {
    error make {msg: "Environment variable IMPROVMX_DOMAIN is required", label: "IMPROVMX_DOMAIN not set"}
  }
  let alias = (input "alias (e, for e@gmail.com)> ")
  let forward = (input "forwarded to > " --default ($env.POP_SMTP_USERNAME | default ""))
  let payload = ({alias: $alias, forward: $forward} | to json)
  let headers = [
    "Authorization" $"Basic api:($env.IMPROVMX_API_KEY)"
    "Content-Type" "application/json"
  ]
  let url = $"https://api.improvmx.com/v3/domains/($env.IMPROVMX_DOMAIN)/aliases"
  http post --headers $headers $url $payload
}

# Proxy through improvmx API - lists all aliases
# Requires: IMPROVMX_API_KEY, IMPROVMX_DOMAIN env vars
# Example: improvmx get
export def "improvmx get" [] {
  if $env.IMPROVMX_API_KEY == null {
    error make {msg: "Environment variable IMPROVMX_API_KEY is required", label: "IMPROVMX_API_KEY not set"}
  }
  if $env.IMPROVMX_DOMAIN == null {
    error make {msg: "Environment variable IMPROVMX_DOMAIN is required", label: "IMPROVMX_DOMAIN not set"}
  }
  let headers = ["Authorization" $"Basic api:($env.IMPROVMX_API_KEY)"]
  let url = $"https://api.improvmx.com/v3/domains/($env.IMPROVMX_DOMAIN)/aliases"
  http get --headers $headers $url | from json
}

# =============================================================================
# Section: GitHub Utilities
# =============================================================================

# Creates a gist from all files in current directory
# Example: gist
export def gist [] {
  let files = (ls | get name | input list -f)
  gh gist create $files
}

# Fuzzy selector for gist ID - returns selected gist record
# Example: gist id
# Output: record with column0 (id) and column1 (filename)
export def "gist id" [n:int = 50] {
  gh gist list -L $n
    | from tsv -n
    | if (which sk | is-not-empty) {
        sk --format {get column1} --preview {}
      } else {
        input list -f -d column1
      }
}

# Edits an existing gist via fuzzy selector
# Example: gist edit
export def "gist edit" [] {
  let id = (gist id | get column0)
  gh gist edit $id
}

# Views a gist via fuzzy selector
# Example: gist view
export def "gist view" [] {
  let id = (gist id | get column0)
  gh gist view $id
}

# Clones a gist via fuzzy selector
# Example: gist clone
export def "gist clone" [] {
  let id = (gist id | get column0)
  gh gist clone $id
}

# Saves a gist's content to a local file
# Example: gist save
export def "gist save" [] {
  let gist_record = (gist id)
  let gist_id = ($gist_record | get column0)
  let filename = ($gist_record | get column1)
  gh gist view $gist_id | save --force $filename
}

# Compiles all .nu files from gists into a single gist.nu
# Example: gist saveall nu
export def "gist saveall nu" [n:int = 50] {
  let nu_gists = (gh gist list -L $n
    | from tsv -n
    | where {|el| ($el.column1 | path parse | get extension) == nu})
  let urls = ($nu_gists | each {|elt| $"https://gist.githubusercontent.com/shaoyanji/($elt.column0)/raw/($elt.column1)"})
  let contents = ($urls | par-each {|elt| http get $elt})
  let combined = ($contents | to text)
  $combined | save --force gist.nu
}

# =============================================================================
# Section: Movies & Entertainment
# =============================================================================

# Returns first search abstract for NYTimes top 100 movies
# Example: movie abstract
export def "movie abstract" [] {
  let gist_id = $CONFIG.gist.movie_list_id
  let movies = (gh gist view $gist_id | split row "\n" | each { str replace -r '^(?:[1-9][0-9]?|100). ' "" } | input list -f)
  let search_term = ($movies | util ddgr)
  $search_term
}

# Opens movie in terminal browser - selects from NYTimes top 100
# Example: movie
export def movie [] {
  let gist_id = $CONFIG.gist.movie_list_id
  let movie_list = (gh gist view $gist_id
    | split row "\n"
    | each { str replace -r '^(?:[1-9][0-9]?|100). ' "" }
    | input list -f
    | ddgr --json --noua
    | from json)
  let selected = ($movie_list | sk --format {get title} --preview {})
  lynx $selected.url
}

# =============================================================================
# Section: Local Media & Files
# =============================================================================

# Plays audiobooks from local volume
# Example: audible
export def audible [] {
  let folder = $CONFIG.volumes.audiobooks
  let ext = "m4b"
  if (which sk | is-not-empty) {
    let books = (glob $"($folder)/**/*.($ext)" | where {str contains '._' | do {not $in}})
    let selected = ($books | sk --format { path parse | get stem} --preview {path parse})
    mpv $selected
  } else {
    let books = (glob $"($folder)/**/*.($ext)" | where {str contains '._' | do {not $in}})
    let selected = ($books | input list -f)
    mpv $selected
  }
}

# Reads QR code from PNG files in current directory
# Example: qrdecode
export def qrdecode [] {
  let images = (glob './**/*.png' | where {str contains '._' | do {not $in}})
  let selected = ($images | sk --format { path parse | get stem} --preview {path parse})
  let path = ($selected | path join)
  let output = (zbarimg $path -q | split row 'QR-Code:' | get 1)
  $output
}

# Parses QR code as URL
# Example: qrdecode | qrdecode url
export def "qrdecode url" [] {
  let qr_content = $in
  url parse $qr_content
}

# Parses QR code as VCF contact
# Example: qrdecode | qrdecode vcf
export def "qrdecode vcf" [] {
  let qr_content = $in
  let parsed = ($qr_content | from csv -n | get column0 | each { parse --regex '(?s)\A(?P<key>.*?):(?P<value>.*?)\z'} | flatten)
  $parsed
}
# Opens PDF files from local volume
# Example: readpdf
export def readpdf [] {
  if (which sk | is-not-empty) {
    let pdfs = (glob $"($CONFIG.volumes.arr)/**/*.pdf")
    let selected = ($pdfs | sk --format { path parse | get stem} --preview {pdfinfo $in} | get 0)
    start $selected
  } else {
    let pdfs = (glob $"($CONFIG.volumes.arr)/**/*.pdf")
    let selected = ($pdfs | input list -f | get 0)
    start $selected
  }
}

# Runs AppImage files from local volume
# Example: appimage
export def appimage [] {
  let folder = $CONFIG.volumes.appimages
  let selected = (glob $"($folder)/*.AppImage" | sk --format { path parse | get stem})
  appimage-run $selected
}

# =============================================================================
# Section: Email (Himalaya)
# =============================================================================

# Fetches and displays emails via himalaya
# Args: num (default 50) - number of emails, w (default 4) - weeks ago
# Example: numail
# Example: numail 100 2
export def numail [
  num: int = 50
  w: int = 4
] {
  let cutoff_date = ($"($w) Weeks ago" | date from-human | format date "%Y-%m-%d")
  let envelopes = (himalaya envelope list -s $num -o json $"after ($cutoff_date)" | from json)
  let selected = ($envelopes | input list -f -d subject)
  let message = (himalaya message -o json read $selected.id | from json | to md)
  glow $message
}

# Multi-select email deletion via himalaya
# Example: numail clean
export def "numail clean" [] {
  let cutoff_date = ("3 Weeks ago" | date from-human | format date "%Y-%m-%d")
  let envelopes = (himalaya envelope list -s 500 -o json $"after ($cutoff_date)" | from json)
  let selected = ($envelopes | sk -m --format {
    $"(ansi red_bold)($in.flags)(ansi reset)(ansi green_dimmed)($in.from.name)(ansi reset)(ansi purple_italic)($in.subject)(ansi reset)"
  } --preview {table --expand})
  $selected | par-each { |msg| himalaya message delete $msg.id }
}

# =============================================================================
# Section: System & Tasks
# =============================================================================

# TOTP code fetcher via cloak
# Example: totp
export def totp [] {
  let accounts = (open ~/.cloak/accounts | from toml | transpose | get column0 | input list -f)
  cloak view $accounts
}

# Todoist task viewer via fuzzy picker
# Example: todo
export def todo [] {
  let tasks = (todoist --csv --header list | from csv)
  let selected = ($tasks | sk --format {} --preview {})
  $selected
}

# Taskfile task runner
# Example: nutask
export def nutask [] {
  let task_output = (task --list-all | from csv | get "task: Available tasks for this project:")
  let task_name = ($task_output | input list | str trim --char "*" | str trim | split column ":" | get column1.0)
  task $task_name
}

# NixOS rebuild with pre-hooks
# Example: rebuild
export def rebuild [] {
  rebuild pre-hooks
  sudo nixos-rebuild switch --flake ~/Documents/nixconfig# o+e>| nom
}

# Pre-hooks for NixOS rebuilds
# Example: rebuild pre-hooks
export def "rebuild pre-hooks" [] {
  nixhash $"($env.HOME)/Documents/nixconfig/modules/config/nu.json"
}

# MicroVM launcher
# Example: launch-microvm
export def "launch-microvm" [] {
  touch .agents workspace
  sudo ip link set microvm1 master $CONFIG.network.microvm_bridge up
  sed -i '/192.168.83.10/d' /home/devji/.ssh/known_hosts
  ssh $CONFIG.network.microvm_ip
}

# =============================================================================
# Section: File Transformation
# =============================================================================

# Builds a PDF from piped string using enscript
# Example: "Hello World" | makepdf output
export def makepdf [name:string] {
  let content = $in
  let ps = (echo $content | enscript -B -fHelvetica10 -p -)
  let pdf = ($ps | ps2pdf - -)
  $pdf | save --force $"($name).pdf"
  mupdf $"($name).pdf"
}

# Builds a graph PDF using graph-easy
# Example: "A->B" | graphpdf mygraph
export def graphpdf [name:string] {
  let content = $in
  let ps = (echo $content | graph-easy --as=ps2)
  let pdf = ($ps | ps2pdf $"($name).ps" -)
  mupdf $"($name).pdf"
}

# Encrypts a file using age with SSH key
# Example: ageencrypt myfile.txt
export def ageencrypt [name:string] {
  let plaintext = (open $name | into string)
  let encrypted = (age -R ~/.ssh/id_ed25519_pub)
  let ciphertext = (do -c { |i| $plaintext | $i } $encrypted)
  $ciphertext | save --force $"($name).age"
}

# Decrypts a file using age with SSH key
# Example: agedecrypt myfile.txt.age
export def agedecrypt [name:string] {
  age -i ~/.ssh/id_ed25519 -d $name
}

# Generates nix hash for a URL (returns hash value)
# Example: nixhash https://example.com/file.tar.gz
export def nixhash [name:string] {
  let url = (open $name | from json | get url | first)
  let hash = ($url | nixhash.sh)
  {url: $url, sha256: $"sha256:($hash)"} | to json | save --force $name
}

# =============================================================================
# Section: Utilities
# =============================================================================

# Notification utility - runs a closure and notifies on completion
# Example: notify on done { sleep 2; echo "done" }
export def "notify on done" [
  task: closure
] {
  let start = (date now)
  let result = (do $task)
  let end = (date now)
  let total = ($end - $start | format duration sec)
  let body = $"Task completed in ($total)"
  if (^which notify | complete | get stdout | is-not-empty) {
    notify -s "Task Finished" -t $body
  } else {
    print $"[notify] (ansi green)Task Finished(ansi reset) - ($body)"
  }
  $result
}
