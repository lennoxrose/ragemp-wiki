// Package report is how the pipeline tells the outside world what it is doing:
// human-readable text for a plain terminal, or NDJSON events for the TS CLI.
package report

// Reporter receives progress from the pipeline. Implementations must be safe
// to call from one goroutine at a time.
type Reporter interface {
	Phase(name string)                      // listing | syncing | indexing
	Listing(n int)                          // pages listed so far
	Plan(total, changed, removed int)       // what this run will do
	Batch(index, size int, titles []string) // a batch started processing
	Page(title, path string)                // a page was written
	Progress(done, total int)               // a batch finished
	Warn(msg string)
	Done(failed int)
	Error(err error)
}
