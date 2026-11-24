package image

// The read-only pool/roster helpers: what the day still holds, the share one
// slot takes, and the roster rows still waiting. These used to be three
// jq/awk passes in image-daily-lib.sh / image-daily-engine.sh; the shell
// callers get the same numbers on stdout from the same inputs (cpg usage,
// the ledger, the roster file).

import (
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// `image-daily remaining` — the day's allowance as a bare number, exactly
// what the shell `remaining` printed: a count, 0, or 1000 for a plan that
// answers "unlimited". An unreadable pool prints nothing — the caller must
// say so rather than spend nothing and call it a full day.
func cmdRemaining() {
	fmt.Print(remaining())
}

// `image-daily share --slots N [--left N]` — ceil(left/slots), clamped to the
// hourly burst ceiling of 25 and to at least one. --left skips the pool read
// for a caller that already asked (today prints both columns from one read).
func cmdShare(args []string) {
	fs := flag.NewFlagSet("share", flag.ExitOnError)
	slots := fs.Int("slots", 1, "slots still to run")
	left := fs.String("left", "", "allowance already known; skips the pool read")
	_ = fs.Parse(args)

	n := *left
	if n == "" {
		n = remaining()
	}
	l, err := strconv.Atoi(strings.TrimSpace(n))
	if err != nil || l < 0 {
		l = 0
	}
	s := *slots
	if s < 1 {
		s = 1
	}
	cap := (l + s - 1) / s
	if cap > 25 {
		cap = 25
	}
	if cap < 1 {
		cap = 1
	}
	fmt.Println(cap)
}

// `image-daily pending --roster PATH` — roster rows with no kept plate: one
// pass over the roster and the ledger, replacing the shell's
// mktemp/sort/comm pipeline.
func cmdPending(args []string) {
	fs := flag.NewFlagSet("pending", flag.ExitOnError)
	roster := fs.String("roster", "", "roster file (pipe-separated)")
	root := fs.String("root", os.Getenv("IMAGES_ROOT"), "image tree root (IMAGES_ROOT)")
	_ = fs.Parse(args)
	if *roster == "" {
		die("pending needs --roster")
	}

	fmt.Println(pendingCount(*root, *roster))
}
