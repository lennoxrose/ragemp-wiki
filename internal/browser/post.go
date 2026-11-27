package browser

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/chromedp/chromedp"
)

const (
	primeURL   = "https://wiki.rage.mp/w/api.php?action=query&meta=siteinfo&format=json"
	maxRetries = 20
)

type postResult struct {
	Status int    `json:"s"`
	Body   string `json:"b"`
}

// PostAPI sends a same-origin POST to api.php from inside the page and decodes
// the JSON reply. Cloudflare rejects such calls from outside the browser, but
// lets them through once the tab has navigated to api.php. 429s are retried.
func (s *Session) PostAPI(params map[string]string, v any) error {
	payload, _ := json.Marshal(params)
	js := `(async()=>{const r=await fetch("/w/api.php",{method:"POST",body:new URLSearchParams(` +
		string(payload) + `)});return JSON.stringify({s:r.status,b:await r.text()})})()`
	for attempt := 0; attempt < maxRetries; attempt++ {
		if !s.primed {
			var skip any
			if err := s.FetchJSON(primeURL, &skip); err != nil {
				return err
			}
		}
		raw, err := chromedp.Run(s.ctx, chromedp.Evaluate[string](js, chromedp.EvalAwaitPromise))
		if err != nil {
			return err
		}
		var res postResult
		if err := json.Unmarshal([]byte(raw), &res); err != nil {
			return err
		}
		switch res.Status {
		case 200:
			return json.Unmarshal([]byte(res.Body), v)
		case 403:
			s.primed = false // challenged again: re-navigate to api.php
		case 429:
			time.Sleep(8 * time.Second)
		default:
			return fmt.Errorf("api POST: HTTP %d", res.Status)
		}
	}
	return fmt.Errorf("api POST: gave up after %d attempts", maxRetries)
}
