package convert

import (
	"regexp"
	"strings"
)

// A fenced block whose only content is a "todo" placeholder, e.g. "// todo".
var todoBlock = regexp.MustCompile("(?is)" + fence + `[a-z]*[ \t]*\n\s*(?://|#|/\*|--)?\s*todo[^\n]*\n\s*` + fence + `[ \t]*\n?`)

const fence = "```"

var heading = regexp.MustCompile(`^(#{1,6})\s+(.*)$`)

type section struct {
	level int
	title string
	lines []string
}

// Clean drops "See also" sections and placeholder todo examples (together with
// the heading that held nothing else).
func Clean(md string) string {
	var out strings.Builder
	skipLevel := 0 // inside a dropped section until a heading of this level or higher
	for _, s := range split(md) {
		if skipLevel > 0 && s.level > skipLevel {
			continue
		}
		skipLevel = 0
		if strings.EqualFold(strings.TrimSpace(s.title), "see also") {
			skipLevel = s.level
			continue
		}
		body := strings.Join(s.lines, "\n")
		cleaned := todoBlock.ReplaceAllString(body+"\n", "")
		if cleaned != body+"\n" && strings.TrimSpace(cleaned) == "" && s.level > 0 {
			continue
		}
		if s.level > 0 {
			out.WriteString(strings.Repeat("#", s.level) + " " + s.title + "\n")
		}
		out.WriteString(strings.TrimRight(cleaned, "\n") + "\n\n")
	}
	return strings.TrimSpace(out.String())
}

func split(md string) []section {
	secs := []section{{}}
	inCode := false
	for _, line := range strings.Split(md, "\n") {
		if strings.HasPrefix(line, "```") {
			inCode = !inCode
		}
		if m := heading.FindStringSubmatch(line); m != nil && !inCode {
			secs = append(secs, section{level: len(m[1]), title: m[2]})
			continue
		}
		last := &secs[len(secs)-1]
		last.lines = append(last.lines, line)
	}
	return secs
}
