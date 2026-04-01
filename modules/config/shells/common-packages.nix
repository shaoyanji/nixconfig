# Common package sets shared across devShells
{pkgs}: {
  # Core utilities - used by most shells
  core = with pkgs; [
    git
    zoxide
    fzf
    bat
    ripgrep
    eza
    lf
    direnv
    fastfetch
    speedtest-cli
    btop
  ];

  # AI tools
  ai = with pkgs; [
    tgpt
    aichat
    mods
  ];

  # UI/UX tools
  ui = with pkgs; [
    gum
    pop
    charm-freeze
    cowsay
    lolcat
  ];

  # Productivity tools
  productivity = with pkgs; [
    go-task
    yq-go
    starship
    sops
    pandoc
  ];

  # Common shell greeting
  greeting = with pkgs; [
    cowsay
    lolcat
  ];

  # Ruby/Jekyll stack
  jekyll = with pkgs; [
    jekyll
    bundler
  ];

  # PDF tooling
  pdf = with pkgs; [
    texlive.combined.scheme-small
    pdfcpu
    poppler-utils
    wkhtmltopdf
    mupdf
    ghostscript
  ];

  # Node.js/Yarn stack
  yarn = with pkgs; [
    yarn
    yarn2nix
  ];

  # Media/download tools
  media = with pkgs; [
    yt-dlp
    mpv
    cmus
    spotube
  ];

  # Editor tools
  editors = with pkgs; [
    helix
    neovim
  ];

  # Python with common packages (using default python3)
  python-flask = pkgs.python3.withPackages (ps: with ps; [
    flask
    fuzzywuzzy
    markdown2
    python-dotenv
  ]);

  # Terminal extras
  terminal-extras = with pkgs; [
    htop
    tldr
    scc
    diff-so-fancy
    entr
    exiftool
    fdupes
    most
    procs
    rsync
    sd
    tre
    bandwhich
    glances
    gping
    buku
    ddgr
    khal
    mutt
    newsboat
    rclone
    tuir
    httpie
    lazygit
    asciinema
    navi
    epr
    lynx
    translate-shell
    mc
    hare
    haredoc
  ];

  # Replit-specific tools
  replit = with pkgs; [
    tmux
    marksman
    dprint
    glow
    sent
    mdp
    wezterm
    meh
    darkhttpd
    surf
    dillo
    qrencode
    imagemagick
    gnuplot
    graph-easy
    graphviz
    librewolf
    alejandra
    slides
    go
    upx
  ];
}
