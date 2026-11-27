// Package useragent builds the User-Agent a normal, non-headless Chrome sends.
// Cloudflare ties its clearance cookie to the User-Agent, so headless mode must
// not announce itself as "HeadlessChrome".
package useragent

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"time"
)

var versionDir = regexp.MustCompile(`^(\d+)\.\d+\.\d+\.\d+$`)
var versionOut = regexp.MustCompile(`(\d+)\.\d+\.\d+\.\d+`)

var platformToken = map[string]string{
	"windows": "Windows NT 10.0; Win64; x64",
	"darwin":  "Macintosh; Intel Mac OS X 10_15_7",
	"linux":   "X11; Linux x86_64",
}

// For returns the User-Agent matching the browser executable's version, or ""
// when the version cannot be determined.
func For(exe string) string {
	major := majorVersion(exe)
	if major == "" {
		return ""
	}
	return fmt.Sprintf("Mozilla/5.0 (%s) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/%s.0.0.0 Safari/537.36",
		platformToken[runtime.GOOS], major)
}

func majorVersion(exe string) string {
	// Windows installs keep a "157.0.8103.79" folder next to chrome.exe.
	if entries, err := os.ReadDir(filepath.Dir(exe)); err == nil {
		for _, e := range entries {
			if m := versionDir.FindStringSubmatch(e.Name()); m != nil {
				return m[1]
			}
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	out, _ := exec.CommandContext(ctx, exe, "--version").Output()
	if m := versionOut.FindStringSubmatch(string(out)); m != nil {
		return m[1]
	}
	return ""
}
