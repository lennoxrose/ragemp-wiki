package main

import (
	"archive/tar"
	"compress/gzip"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fakePanel records what the panel would write: path -> content, and removals.
func fakePanel(t *testing.T) (*httptest.Server, map[string]string, *[]string, *int) {
	files, removed, posts := map[string]string{}, &[]string{}, new(int)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*posts++
		gz, err := gzip.NewReader(r.Body)
		if err != nil {
			t.Error(err)
			return
		}
		tr := tar.NewReader(gz)
		for {
			h, err := tr.Next()
			if err == io.EOF {
				break
			}
			b, _ := io.ReadAll(tr)
			if h.Name == deletedList {
				*removed = append(*removed, strings.Split(string(b), "\n")...)
			} else {
				files[h.Name] = string(b)
			}
		}
		w.Write([]byte("{}"))
	}))
	return srv, files, removed, posts
}

func TestUploadSendsOnlyChanges(t *testing.T) {
	out := t.TempDir()
	write := func(rel, body string) {
		p := filepath.Join(out, filepath.FromSlash(rel))
		os.MkdirAll(filepath.Dir(p), 0o755)
		os.WriteFile(p, []byte(body), 0o644)
	}
	write("Cat/content/A.md", "a")
	write("Cat/content/B.md", "b")
	write(".manifest.json", "{}")
	srv, files, removed, posts := fakePanel(t)
	defer srv.Close()
	a := &agent{cfg: config{Server: srv.URL, Out: out}, dir: t.TempDir(), http: srv.Client(), state: map[string]fileState{}}

	if err := a.upload(1); err != nil || len(files) != 3 || files["Cat/content/A.md"] != "a" {
		t.Fatalf("first upload: err=%v files=%v", err, files)
	}
	n := *posts
	if err := a.upload(1); err != nil || *posts != n {
		t.Fatalf("unchanged tree must send nothing: err=%v posts %d->%d", err, n, *posts)
	}

	write("Cat/content/A.md", "a2")
	os.Chtimes(filepath.Join(out, "Cat/content/A.md"), time.Now().Add(time.Hour), time.Now().Add(time.Hour))
	os.Remove(filepath.Join(out, "Cat/content/B.md"))
	clear(files)
	if err := a.upload(1); err != nil || files["Cat/content/A.md"] != "a2" || len(files) != 1 || len(*removed) != 1 || (*removed)[0] != "Cat/content/B.md" {
		t.Fatalf("second upload: err=%v files=%v removed=%v", err, files, *removed)
	}
}
