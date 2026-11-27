package report

import "fmt"

// Text prints a compact human-readable log.
type Text struct{}

func (Text) Phase(name string)        { fmt.Printf("\n[%s]\n", name) }
func (Text) Listing(n int)            { fmt.Printf("\r  %d pages", n) }
func (Text) Warn(msg string)          { fmt.Printf("\n  WARN %s\n", msg) }
func (Text) Error(err error)          { fmt.Printf("\nerror: %v\n", err) }
func (Text) Batch(int, int, []string) {}
func (Text) Page(string, string)      {}

func (Text) Plan(total, changed, removed int) {
	fmt.Printf("\n%d total, %d to fetch, %d removed\n", total, changed, removed)
}

func (Text) Progress(done, total int) { fmt.Printf("\r  %d/%d", done, total) }

func (Text) Done(failed int) {
	fmt.Printf("\ndone: %d batches failed (they retry on the next run)\n", failed)
}
