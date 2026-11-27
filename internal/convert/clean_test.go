package convert

import (
	"strings"
	"testing"
)

func TestClean(t *testing.T) {
	in := "Intro text.\n\n## Syntax\n\n```\nfoo();\n```\n\n## Example\n\n```\n// todo\n```\n\n## See also\n\n- [a](b)\n\n### Sub\n\nx\n\n## Notes\n\nkeep me"
	out := Clean(in)
	for _, bad := range []string{"todo", "See also", "Example", "[a]", "Sub"} {
		if strings.Contains(out, bad) {
			t.Errorf("output still contains %q:\n%s", bad, out)
		}
	}
	for _, good := range []string{"Intro text.", "## Syntax", "foo();", "## Notes", "keep me"} {
		if !strings.Contains(out, good) {
			t.Errorf("output lost %q:\n%s", good, out)
		}
	}
}
