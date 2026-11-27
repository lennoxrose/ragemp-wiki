package convert

import (
	"regexp"
	"strings"
)

var (
	mdLink  = regexp.MustCompile(`!?\[([^\]]*)\]\([^)]*\)`)
	mdNoise = strings.NewReplacer("**", "", "*", "", "`", "", "\\", "", "|", "/")
)

const maxSummary = 100

// Summary returns the first prose line of the page, flattened for use in an index.
func Summary(md string) string {
	for _, line := range strings.Split(md, "\n") {
		l := strings.TrimSpace(line)
		if l == "" || strings.ContainsAny(l[:1], "#|>-+=") || strings.HasPrefix(l, "```") {
			continue
		}
		l = strings.TrimSpace(mdNoise.Replace(mdLink.ReplaceAllString(l, "$1")))
		if len([]rune(l)) < 12 {
			continue
		}
		if r := []rune(l); len(r) > maxSummary {
			l = string(r[:maxSummary]) + "…"
		}
		return l
	}
	return ""
}
