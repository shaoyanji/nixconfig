set E:XDG_DATA_HOME = ~/.config
eval (starship init elvish)
use epm
use github.com/xiaq/edit.elv/smart-matcher
smart-matcher:apply
use github.com/xiaq/edit.elv/compl/git
git:apply
use github.com/xiaq/edit.elv/compl/go
go:apply
use github.com/zzamboni/elvish-modules/nix
eval (zoxide init elvish | slurp)
