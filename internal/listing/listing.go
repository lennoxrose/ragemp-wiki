// Package listing enumerates every wiki page with its latest revision id.
package listing

import (
	"fmt"
	"net/url"
)

const api = "https://wiki.rage.mp/w/api.php"

type Page struct {
	ID    int    `json:"pageid"`
	NS    int    `json:"ns"`
	Title string `json:"title"`
	RevID int    `json:"lastrevid"`
}

// JSONFetcher loads an API URL and decodes the JSON response (the browser session).
type JSONFetcher interface {
	FetchJSON(url string, v any) error
}

type response struct {
	Continue map[string]string `json:"continue"`
	Query    struct {
		Pages []Page `json:"pages"`
	} `json:"query"`
}

// All lists the non-redirect pages of one namespace, 500 per request.
func All(f JSONFetcher, ns int, progress func(n int)) ([]Page, error) {
	var pages []Page
	cont := url.Values{}
	for {
		q := url.Values{
			"action": {"query"}, "format": {"json"}, "formatversion": {"2"},
			"generator": {"allpages"}, "gapnamespace": {fmt.Sprint(ns)},
			"gapfilterredir": {"nonredirects"}, "gaplimit": {"500"}, "prop": {"info"},
		}
		for k, v := range cont {
			q[k] = v
		}
		var r response
		if err := f.FetchJSON(api+"?"+q.Encode(), &r); err != nil {
			return nil, err
		}
		pages = append(pages, r.Query.Pages...)
		if progress != nil {
			progress(len(pages))
		}
		if len(r.Continue) == 0 {
			return pages, nil
		}
		cont = url.Values{}
		for k, v := range r.Continue {
			cont.Set(k, v)
		}
	}
}
