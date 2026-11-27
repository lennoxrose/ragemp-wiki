// Package convert turns a rendered MediaWiki fragment into Markdown.
package convert

import (
	"strings"

	htmltomarkdown "github.com/JohannesKaufmann/html-to-markdown/v2"
	"github.com/JohannesKaufmann/html-to-markdown/v2/converter"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/base"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/commonmark"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/table"
	"github.com/PuerkitoBio/goquery"
)

const domain = "https://wiki.rage.mp"

// Result is one converted page.
type Result struct {
	Markdown   string
	Categories []string // without maintenance categories such as "TODO: Example"
}

var noise = ".mw-editsection, .toc, #toc, script, style, .printfooter, .mw-empty-elt, .noprint, .navbox, img"

var conv = converter.NewConverter(converter.WithPlugins(
	base.NewBasePlugin(), commonmark.NewCommonmarkPlugin(), table.NewTablePlugin(),
))

// Page converts the rendered HTML of one page body and filters its categories.
func Page(fragment string, categories []string) (Result, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader("<div>" + fragment + "</div>"))
	if err != nil {
		return Result{}, err
	}
	doc.Find(noise).Remove()
	inner, err := doc.Find("body").Html()
	if err != nil {
		return Result{}, err
	}
	md, err := htmltomarkdown.ConvertString(inner, converter.WithDomain(domain))
	if err != nil {
		return Result{}, err
	}
	var cats []string
	for _, c := range categories {
		if !isMaintenance(c) {
			cats = append(cats, c)
		}
	}
	return Result{Markdown: Clean(md), Categories: cats}, nil
}

// isMaintenance flags housekeeping categories: editor "TODO: ..." markers and
// MediaWiki tracking categories such as "Pages with syntax highlighting errors".
func isMaintenance(cat string) bool {
	return strings.HasPrefix(strings.ToUpper(cat), "TODO") || strings.HasPrefix(cat, "Pages with ")
}
