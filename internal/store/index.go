package store

import (
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"ragemp-wiki/internal/manifest"
)

// Mode selects the output flavour. Both modes share the same file layout.
type Mode string

const (
	Vault   Mode = "vault"   // Obsidian wikilinks plus a colored .obsidian config
	Compile Mode = "compile" // plain Markdown links, nothing Obsidian-specific
)

type item struct{ title, path, summary string }

// link renders a reference to `target` (a path relative to the page that
// contains it) in the syntax of the chosen mode.
func (m Mode) link(label, target string) string {
	label = strings.ReplaceAll(label, "|", "/")
	if m == Vault {
		return fmt.Sprintf("[[%s|%s]]", strings.TrimSuffix(target, ".md"), label)
	}
	return fmt.Sprintf("[%s](%s)", label, (&url.URL{Path: target}).EscapedPath())
}

// WriteIndexes builds the navigation layer: index.md links to every
// <Category>/<Category>_index.md, and each category index links to every page in
// that category (summary included). In vault mode it also writes .obsidian/.
func WriteIndexes(root string, m *manifest.Manifest, mode Mode) error {
	byCat := map[string][]item{}
	for title, e := range m.Entries {
		cats := e.Categories
		if len(cats) == 0 {
			cats = []string{Uncategorized}
		}
		for _, c := range cats {
			byCat[Clean(c)] = append(byCat[Clean(c)], item{title, e.Path, e.Summary})
		}
	}
	names := make([]string, 0, len(byCat))
	for c := range byCat {
		names = append(names, c)
	}
	sort.Strings(names)

	var top strings.Builder
	fmt.Fprintf(&top, "# RAGE MP Wiki\n\n%d pages in %d categories. Open a category index to see its pages.\n\n", len(m.Entries), len(names))
	for _, c := range names {
		fmt.Fprintf(&top, "- %s (%d)\n", mode.link(c, c+"/"+c+"_index.md"), len(byCat[c]))
		if err := writeCategory(root, c, byCat[c], mode); err != nil {
			return err
		}
	}
	if err := os.WriteFile(filepath.Join(root, "index.md"), []byte(top.String()), 0o644); err != nil {
		return err
	}
	if mode == Vault {
		return WriteObsidian(root, names)
	}
	return nil
}

func writeCategory(root, cat string, items []item, mode Mode) error {
	sort.Slice(items, func(i, j int) bool { return items[i].title < items[j].title })
	back := "index.md"
	if mode == Compile {
		back = "../index.md"
	}
	var b strings.Builder
	fmt.Fprintf(&b, "# %s\n\n%s · %d pages\n\n", cat, mode.link("← All categories", back), len(items))
	for _, it := range items {
		target := it.path // vault links are vault-root relative, compile links are folder relative
		if mode == Compile {
			target = "../" + it.path
		}
		fmt.Fprintf(&b, "- %s", mode.link(it.title, target))
		if it.summary != "" {
			fmt.Fprintf(&b, " — %s", it.summary)
		}
		b.WriteString("\n")
	}
	dir := filepath.Join(root, cat)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, cat+"_index.md"), []byte(b.String()), 0o644)
}
