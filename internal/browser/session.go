package browser

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/chromedp/chromedp"
	"github.com/chromedp/chromedp/remote"

	"ragemp-wiki/internal/chromium"
)

// Session is a tab attached to the debug-port browser.
type Session struct {
	ctx     context.Context
	cancel  []context.CancelFunc
	started bool
	port    int
	primed  bool // the tab sits on an api.php page, so same-origin POSTs are allowed
}

func Connect(port int) (*Session, error) {
	started, err := ensureRunning(port)
	if err != nil {
		return nil, err
	}
	alloc, c1 := remote.NewAllocator(context.Background(), fmt.Sprintf("http://127.0.0.1:%d", port))
	ctx, c2 := chromedp.NewContext(alloc)
	return &Session{ctx: ctx, cancel: []context.CancelFunc{c2, c1}, started: started, port: port}, nil
}

// Close detaches; when this process launched the browser it is shut down too.
func (s *Session) Close() {
	for _, c := range s.cancel {
		c()
	}
	if s.started {
		if err := chromium.Shutdown(s.port); err != nil {
			fmt.Fprintln(os.Stderr, "close browser:", err)
		}
	}
}

// waitBody navigates and polls until the body satisfies ok (Cloudflare shows
// "Just a moment" first and then redirects to the real response).
func (s *Session) waitBody(url string, wait time.Duration, ok func(string) bool) (string, error) {
	if _, err := chromedp.Run(s.ctx, chromedp.Navigate(url)); err != nil {
		return "", err
	}
	deadline := time.Now().Add(wait)
	for time.Now().Before(deadline) {
		js := `document.body ? document.body.innerText : ""`
		if body, err := chromedp.Run(s.ctx, chromedp.Evaluate[string](js)); err == nil && ok(body) {
			return body, nil
		}
		time.Sleep(700 * time.Millisecond)
	}
	return "", fmt.Errorf("timeout waiting for %s", url)
}

// FetchJSON loads an API URL as a page navigation and decodes the JSON body.
// A rate-limited (429) or still-challenged page never turns into JSON, so the
// navigation is retried after a pause.
func (s *Session) FetchJSON(url string, v any) error {
	isJSON := func(b string) bool { return strings.HasPrefix(strings.TrimSpace(b), "{") }
	var lastErr error
	for attempt := 0; attempt < 6; attempt++ {
		body, err := s.waitBody(url, 25*time.Second, isJSON)
		if err == nil {
			s.primed = strings.Contains(url, "/w/api.php")
			return json.Unmarshal([]byte(body), v)
		}
		lastErr = err
		time.Sleep(time.Duration(10+attempt*10) * time.Second)
	}
	return lastErr
}
