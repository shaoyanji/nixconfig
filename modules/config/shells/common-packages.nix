# Common package sets shared across devShells
{pkgs}: {
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

  ai = with pkgs; [
    tgpt
    aichat
    mods
  ];

  ui = with pkgs; [
    gum
    pop
    charm-freeze
    cowsay
    lolcat
  ];

  productivity = with pkgs; [
    go-task
    yq-go
    starship
    sops
    pandoc
  ];

  greeting = with pkgs; [
    cowsay
    lolcat
  ];

  jekyll = with pkgs; [
    jekyll
    bundler
  ];

  pdf = with pkgs; [
    texlive.combined.scheme-small
    pdfcpu
    poppler-utils
    wkhtmltopdf
    mupdf
    ghostscript
  ];

  yarn = with pkgs; [
    yarn
  ];

  media = with pkgs; [
    yt-dlp
    mpv
    cmus
    spotube
  ];

  editors = with pkgs; [
    helix
    neovim
  ];

  # Python with common packages (using default python3)
  python-flask = pkgs.python3.withPackages (ps:
    with ps; [
      flask
      fuzzywuzzy
      markdown2
      python-dotenv
    ]);

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
