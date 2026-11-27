// Package store writes pages as Markdown files grouped by category.
package store

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"ragemp-wiki/internal/listing"
)

const Uncategorized = "Uncategorized"

// Also strips # ^ [ ] which Obsidian cannot handle in note names.
var bad = regexp.MustCompile(`[<>:"/\\|?*#^\[\]\x00-\x1f]+`)

// Clean makes a title safe as a file or folder name on every OS.
func Clean(s string) string {
	s = strings.Trim(bad.ReplaceAllString(strings.TrimSpace(s), "_"), " .")
	if len(s) > 120 {
		s = s[:120]
	}
	if s == "" {
		return "_"
	}
	return s
}

// RelPath is the slash-separated location of a page: <primary category>/content/<title>.md.
func RelPath(title string, cats []string) string {
	dir := Uncategorized
	if len(cats) > 0 {
		dir = cats[0]
	}
	return Clean(dir) + "/content/" + Clean(title) + ".md"
}

// Write saves one page with YAML front matter.
func Write(root, rel string, p listing.Page, cats []string, md string) error {
	var b strings.Builder
	fmt.Fprintf(&b, "---\ntitle: %q\npageid: %d\nrevid: %d\nurl: %q\n", p.Title, p.ID, p.RevID, pageURL(p.Title))
	fmt.Fprintf(&b, "categories: [%s]\nfetched: %s\n---\n\n# %s\n\n%s\n",
		quoteAll(cats), time.Now().UTC().Format(time.RFC3339), p.Title, md)
	full := filepath.Join(root, filepath.FromSlash(rel))
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		return err
	}
	return os.WriteFile(full, []byte(b.String()), 0o644)
}

// Remove deletes a page file; a missing file is fine.
func Remove(root, rel string) {
	_ = os.Remove(filepath.Join(root, filepath.FromSlash(rel)))
}

func pageURL(title string) string {
	return "https://wiki.rage.mp/wiki/" + strings.ReplaceAll(title, " ", "_")
}

func quoteAll(ss []string) string {
	q := make([]string, len(ss))
	for i, s := range ss {
		q[i] = fmt.Sprintf("%q", s)
	}
	return strings.Join(q, ", ")
}
