// Package content loads batches of pages through the MediaWiki API: wikitext and
// categories first, then one combined parse call that renders them all to HTML.
package content

import (
	"strings"
)

// Poster sends an api.php POST and decodes the JSON reply (the browser session).
type Poster interface {
	PostAPI(params map[string]string, v any) error
}

// Doc is one loaded page.
type Doc struct {
	Wikitext   string
	Categories []string
	HTML       string
}

type queryReply struct {
	Continue map[string]string `json:"continue"`
	Query    struct {
		Pages []struct {
			Title     string `json:"title"`
			Missing   bool   `json:"missing"`
			Revisions []struct {
				Slots struct {
					Main struct {
						Content string `json:"content"`
					} `json:"main"`
				} `json:"slots"`
			} `json:"revisions"`
			Categories []struct {
				Title string `json:"title"`
			} `json:"categories"`
		} `json:"pages"`
	} `json:"query"`
}

// loadWikitext fetches wikitext and categories for up to 50 titles.
func loadWikitext(p Poster, titles []string) (map[string]*Doc, error) {
	docs := map[string]*Doc{}
	cont := map[string]string{}
	for {
		params := map[string]string{
			"action": "query", "format": "json", "formatversion": "2",
			"prop": "revisions|categories", "rvprop": "content", "rvslots": "main",
			"cllimit": "max", "clshow": "!hidden", "titles": strings.Join(titles, "|"),
		}
		for k, v := range cont {
			params[k] = v
		}
		var r queryReply
		if err := p.PostAPI(params, &r); err != nil {
			return nil, err
		}
		for _, pg := range r.Query.Pages {
			if pg.Missing {
				continue
			}
			d := docs[pg.Title]
			if d == nil {
				d = &Doc{}
				docs[pg.Title] = d
			}
			if len(pg.Revisions) > 0 {
				d.Wikitext = pg.Revisions[0].Slots.Main.Content
			}
			for _, c := range pg.Categories {
				d.Categories = append(d.Categories, strings.TrimPrefix(c.Title, "Category:"))
			}
		}
		if len(r.Continue) == 0 {
			return docs, nil
		}
		cont = r.Continue
	}
}
