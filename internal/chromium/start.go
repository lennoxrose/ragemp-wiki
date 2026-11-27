package chromium

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"ragemp-wiki/internal/useragent"
)

// Options configures one browser start.
type Options struct {
	Port      int
	URL       string
	Show      bool   // visible window instead of headless (to solve a challenge by hand)
	UserAgent string // normal-Chrome User-Agent; computed when empty
}

// Info is what the debug endpoint reports about a running browser.
type Info struct {
	Browser              string `json:"Browser"`
	WebSocketDebuggerURL string `json:"webSocketDebuggerUrl"`
}

// Probe asks the debug port whether a browser is listening.
func Probe(port int) (Info, bool) {
	c := http.Client{Timeout: 2 * time.Second}
	resp, err := c.Get(fmt.Sprintf("http://127.0.0.1:%d/json/version", port))
	if err != nil {
		return Info{}, false
	}
	defer resp.Body.Close()
	var info Info
	return info, resp.StatusCode == 200 && json.NewDecoder(resp.Body).Decode(&info) == nil
}

// Start launches the browser detached from this process (it keeps running after
// we exit) and waits until its debug port answers. An already running browser is reused.
func Start(o Options) (Info, bool, error) {
	if info, ok := Probe(o.Port); ok {
		return info, false, nil
	}
	exe, err := Find()
	if err != nil {
		return Info{}, false, err
	}
	cache, _ := os.UserCacheDir()
	profile := filepath.Join(cache, "wikisync", "chromium-profile")
	if err := os.MkdirAll(profile, 0o755); err != nil {
		return Info{}, false, err
	}
	args := []string{
		fmt.Sprintf("--remote-debugging-port=%d", o.Port), "--remote-allow-origins=*",
		"--user-data-dir=" + profile, "--no-first-run", "--no-default-browser-check",
		"--lang=en-US", "--disable-features=Translate,TranslateUI,TranslateSubFrames",
		"--disable-renderer-backgrounding", "--disable-background-timer-throttling",
		"--disable-backgrounding-occluded-windows", "--disable-blink-features=AutomationControlled",
	}
	ua := o.UserAgent
	if ua == "" {
		ua = useragent.For(exe)
	}
	if ua != "" {
		args = append(args, "--user-agent="+ua)
	}
	if os.Getenv("CHROMIUM_NO_SANDBOX") != "" { // containers: no user namespaces, tiny /dev/shm
		args = append(args, "--no-sandbox", "--disable-dev-shm-usage")
	}
	if !o.Show {
		args = append(args, "--headless=new", "--window-size=1280,800")
	}
	cmd := exec.Command(exe, append(args, o.URL)...)
	detach(cmd, !o.Show)
	if err := cmd.Start(); err != nil {
		return Info{}, false, err
	}
	_ = cmd.Process.Release()
	for i := 0; i < 120; i++ { // Chromium can take a while on a cold start
		time.Sleep(500 * time.Millisecond)
		if info, ok := Probe(o.Port); ok {
			return info, true, nil
		}
	}
	return Info{}, false, fmt.Errorf("browser started but port %d never opened", o.Port)
}
