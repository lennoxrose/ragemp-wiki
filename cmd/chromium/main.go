// wikisync-chromium starts the headless browser with a debug port and leaves it
// running in the background. wikisync calls it whenever it needs the browser.
package main

import (
	"flag"
	"fmt"
	"os"

	"ragemp-wiki/internal/chromium"
)

func main() {
	var o chromium.Options
	flag.IntVar(&o.Port, "port", 9222, "remote debugging port")
	flag.StringVar(&o.URL, "url", "https://wiki.rage.mp/wiki/Main_Page", "page to open")
	flag.BoolVar(&o.Show, "show", false, "visible window instead of headless")
	flag.Parse()

	info, started, err := chromium.Start(o)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
	if !started {
		fmt.Printf("Already running on port %d: %s\n", o.Port, info.Browser)
		return
	}
	fmt.Printf("Ready: %s\nDebug endpoint: %s\n", info.Browser, info.WebSocketDebuggerURL)
}
