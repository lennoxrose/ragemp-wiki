package report

import (
	"encoding/json"
	"io"
	"sync"
	"time"
)

// JSON writes one event per line (NDJSON); the TS CLI consumes this stream.
type JSON struct {
	mu  sync.Mutex
	enc *json.Encoder
}

func NewJSON(w io.Writer) *JSON { return &JSON{enc: json.NewEncoder(w)} }

func (j *JSON) emit(t string, fields map[string]any) {
	j.mu.Lock()
	defer j.mu.Unlock()
	fields["t"], fields["ts"] = t, time.Now().UnixMilli()
	_ = j.enc.Encode(fields)
}

func (j *JSON) Phase(name string) { j.emit("phase", map[string]any{"name": name}) }
func (j *JSON) Listing(n int)     { j.emit("listing", map[string]any{"count": n}) }
func (j *JSON) Warn(msg string)   { j.emit("warn", map[string]any{"msg": msg}) }
func (j *JSON) Error(err error)   { j.emit("error", map[string]any{"msg": err.Error()}) }
func (j *JSON) Done(failed int)   { j.emit("done", map[string]any{"failed": failed}) }

func (j *JSON) Plan(total, changed, removed int) {
	j.emit("plan", map[string]any{"total": total, "changed": changed, "removed": removed})
}

func (j *JSON) Batch(index, size int, titles []string) {
	j.emit("batch", map[string]any{"index": index, "size": size, "titles": titles})
}

func (j *JSON) Page(title, path string) {
	j.emit("page", map[string]any{"title": title, "path": path})
}

func (j *JSON) Progress(done, total int) {
	j.emit("progress", map[string]any{"done": done, "total": total})
}
