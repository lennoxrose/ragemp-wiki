// Package chromium finds, configures and starts the headless browser whose
// debug port the wiki client uses to pass Cloudflare.
package chromium

import (
	"fmt"
	"os"
	"path/filepath"
)

// Find returns the first installed Chromium-based browser, honouring CHROMIUM_PATH.
func Find() (string, error) {
	local, pf := os.Getenv("LOCALAPPDATA"), os.Getenv("ProgramFiles")
	home, _ := os.UserHomeDir()
	candidates := []string{
		os.Getenv("CHROMIUM_PATH"),
		filepath.Join(local, `Chromium\Application\chrome.exe`),
		filepath.Join(local, `Google\Chrome\Application\chrome.exe`),
		filepath.Join(pf, `Google\Chrome\Application\chrome.exe`),
		filepath.Join(pf, `Microsoft\Edge\Application\msedge.exe`),
		"/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome",
		"/Applications/Chromium.app/Contents/MacOS/Chromium",
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
		filepath.Join(home, ".local/bin/chromium"),
	}
	for _, c := range candidates {
		if c == "" {
			continue
		}
		if _, err := os.Stat(c); err == nil {
			return c, nil
		}
	}
	return "", fmt.Errorf("no Chromium-based browser found; set CHROMIUM_PATH")
}
