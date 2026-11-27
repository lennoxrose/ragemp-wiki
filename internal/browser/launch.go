// Package browser drives the headless Chromium debug port, which is only
// needed to pass Cloudflare for API calls.
package browser

import "ragemp-wiki/internal/chromium"

// ensureRunning starts the browser when the debug port is closed, through
// wikisync-chromium.dll when present and through the built-in code otherwise.
// It reports whether this call started the browser.
func ensureRunning(port int) (bool, error) {
	if _, ok := chromium.Probe(port); ok {
		return false, nil
	}
	if started, used, err := startViaDLL(port); used {
		return started, err
	}
	_, started, err := chromium.Start(chromium.Options{Port: port, URL: "https://wiki.rage.mp/wiki/Main_Page"})
	return started, err
}
