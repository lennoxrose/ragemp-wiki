package content

import (
	"fmt"
	"regexp"
	"strings"
)

var marker = regexp.MustCompile(`<div[^>]*id="wsx-(\d+)"[^>]*></div>`)

// Load fetches and renders a batch of pages (keep it to ~25 titles). The result
// is keyed by title; missing pages are simply absent.
func Load(p Poster, titles []string) (map[string]*Doc, error) {
	docs, err := loadWikitext(p, titles)
	if err != nil {
		return nil, err
	}
	var order []string
	var text strings.Builder
	for _, t := range titles {
		if d, ok := docs[t]; ok {
			fmt.Fprintf(&text, "\n\n<div id=\"wsx-%d\"></div>\n\n%s", len(order), d.Wikitext)
			order = append(order, t)
		}
	}
	if len(order) == 0 {
		return docs, nil
	}
	var r struct {
		Parse struct {
			Text string `json:"text"`
		} `json:"parse"`
	}
	err = p.PostAPI(map[string]string{
		"action": "parse", "format": "json", "formatversion": "2", "prop": "text",
		"contentmodel": "wikitext", "disablelimitreport": "1", "disableeditsection": "1",
		"disabletoc": "1", "text": text.String(),
	}, &r)
	if err != nil {
		return nil, err
	}
	parts := marker.Split(r.Parse.Text, -1) // parts[0] is the wrapper before marker 0
	if len(parts) != len(order)+1 {
		return nil, fmt.Errorf("render: expected %d page breaks, got %d", len(order), len(parts)-1)
	}
	for i, t := range order {
		docs[t].HTML = parts[i+1]
	}
	return docs, nil
}
