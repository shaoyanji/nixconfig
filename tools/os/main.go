// Command os is the fleet's single CLI of the operating system: one binary,
// one go.mod, domains under internal/. A caller reaches a domain either as
// `os <domain> <verb>` or through a per-tool argv[0] alias (the busybox
// shape) — .#cli.<family>.<tool> packages symlink their tool name back onto
// this binary, so `image-daily manifest` and `os image manifest` are the same
// call and no task or script changes when a domain folds in.
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"nixconfig/os/internal/image"
	"nixconfig/os/internal/serve"
)

var domains = map[string]func([]string){
	"image":        image.Main,
	"image-daily":  image.Main, // argv[0] alias installed by .#cli.image.daily
	"serve":        serve.Main,
	"static-serve": serve.Main, // argv[0] alias installed by .#cli.serve.static-serve
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: os <domain> <verb> [flags]  (domains: image, serve)")
	os.Exit(2)
}

func main() {
	args := os.Args[1:]
	domain, ok := domains[filepath.Base(os.Args[0])]
	if !ok {
		// Called as `os`: the next word is the domain, and the family form
		// `os image daily <verb>` resolves to the same verb table.
		if len(args) == 0 {
			usage()
		}
		name := args[0]
		args = args[1:]
		if domain, ok = domains[name]; !ok {
			fmt.Fprintf(os.Stderr, "os: unknown domain %q\n", name)
			usage()
		}
	}
	if len(args) > 0 && args[0] == "daily" {
		args = args[1:]
	}
	domain(args)
}
