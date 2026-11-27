package store

import (
	"encoding/json"
	"fmt"
	"hash/fnv"
	"image/color"
	"math"
	"os"
	"path/filepath"
	"strings"
)

const snippetName = "rage-categories"

// colorFor derives a stable, vivid color from a category name, so a category
// keeps its color across runs no matter which other categories exist.
func colorFor(name string) color.RGBA {
	h := fnv.New32a()
	h.Write([]byte(name))
	hue := float64(h.Sum32()%3600) / 10
	return hsl(hue, 0.72, 0.62)
}

func hsl(h, s, l float64) color.RGBA {
	c := (1 - math.Abs(2*l-1)) * s
	x := c * (1 - math.Abs(math.Mod(h/60, 2)-1))
	m := l - c/2
	var r, g, b float64
	switch int(h / 60) {
	case 0:
		r, g, b = c, x, 0
	case 1:
		r, g, b = x, c, 0
	case 2:
		r, g, b = 0, c, x
	case 3:
		r, g, b = 0, x, c
	case 4:
		r, g, b = x, 0, c
	default:
		r, g, b = c, 0, x
	}
	to := func(v float64) uint8 { return uint8(math.Round((v + m) * 255)) }
	return color.RGBA{to(r), to(g), to(b), 255}
}

// WriteObsidian makes dist/ a ready-made vault: graph colors per category,
// golden index notes, and a CSS snippet that tints the file explorer.
func WriteObsidian(root string, categories []string) error {
	dir := filepath.Join(root, ".obsidian")
	if err := os.MkdirAll(filepath.Join(dir, "snippets"), 0o755); err != nil {
		return err
	}
	gold := color.RGBA{255, 200, 40, 255}
	groups := []any{group("file:_index", gold)}
	var css strings.Builder
	css.WriteString(".nav-file-title[data-path$=\"_index.md\"] { color: #ffc828; font-weight: 600; }\n")
	for _, c := range categories {
		col := colorFor(c)
		groups = append(groups, group(fmt.Sprintf("path:%q", c+"/"), col))
		fmt.Fprintf(&css, ".nav-folder-title[data-path=%q], .nav-folder-title[data-path^=%q], .nav-file-title[data-path^=%q] { color: #%02x%02x%02x; }\n",
			c, c+"/", c+"/", col.R, col.G, col.B)
	}
	err := mergeJSON(filepath.Join(dir, "graph.json"), map[string]any{"colorGroups": groups})
	if err != nil {
		return err
	}
	if err := mergeJSON(filepath.Join(dir, "appearance.json"), map[string]any{"enabledCssSnippets": []string{snippetName}}); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "snippets", snippetName+".css"), []byte(css.String()), 0o644)
}

func group(query string, c color.RGBA) map[string]any {
	rgb := int(c.R)<<16 | int(c.G)<<8 | int(c.B)
	return map[string]any{"query": query, "color": map[string]any{"a": 1, "rgb": rgb}}
}

// mergeJSON overwrites only the given keys, keeping the user's other settings.
func mergeJSON(path string, set map[string]any) error {
	cur := map[string]any{}
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, &cur)
	}
	for k, v := range set {
		cur[k] = v
	}
	b, err := json.MarshalIndent(cur, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}
