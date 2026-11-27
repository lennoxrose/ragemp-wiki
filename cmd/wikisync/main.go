// wikisync mirrors the RAGE MP wiki into dist/ as Markdown, updating only changed pages.
package main

import (
	"flag"
	"fmt"
	"os"

	"ragemp-wiki/internal/pipeline"
	"ragemp-wiki/internal/report"
	"ragemp-wiki/internal/store"
)

func main() {
	var o pipeline.Options
	flag.StringVar(&o.Out, "out", "dist", "output directory")
	flag.IntVar(&o.NS, "ns", 0, "wiki namespace to mirror (0 = main articles)")
	flag.IntVar(&o.Batch, "batch", 50, "pages rendered per API call")
	flag.IntVar(&o.Port, "port", 9222, "Chromium debug port")
	flag.BoolVar(&o.Full, "full", false, "refetch every page, ignoring the manifest")
	flag.IntVar(&o.Limit, "limit", 0, "fetch at most N pages (testing)")
	mode := flag.String("mode", "vault", "vault = Obsidian vault with colors; compile = plain Markdown, same layout")
	asJSON := flag.Bool("json", false, "emit NDJSON progress events on stdout (used by the CLI)")
	flag.Parse()
	o.Mode = store.Mode(*mode)
	if o.Mode != store.Vault && o.Mode != store.Compile {
		fmt.Fprintln(os.Stderr, "error: -mode must be vault or compile")
		os.Exit(2)
	}
	o.Rep = report.Text{}
	if *asJSON {
		o.Rep = report.NewJSON(os.Stdout)
	}
	if err := pipeline.Run(o); err != nil {
		o.Rep.Error(err)
		os.Exit(1)
	}
}
