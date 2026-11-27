package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// chunkBytes keeps each upload under the default 1 MB request limit of nginx in front of the panel.
const (
	chunkBytes  = 700 << 10
	deletedList = ".wikisync-deleted" // the entry the panel reads as "paths to remove"
	deleteChunk = 2000
)

type fileState struct {
	Size int64 `json:"size"`
	Mod  int64 `json:"mod"`
}

func loadState(path string) map[string]fileState {
	s := map[string]fileState{}
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, &s)
	}
	return s
}

func (a *agent) saveState() {
	if b, err := json.Marshal(a.state); err == nil {
		_ = os.WriteFile(a.statePath(), b, 0o600)
	}
}

// scan lists every file under dir with its size and modification time, keyed by slash path.
func scan(dir string) (map[string]fileState, error) {
	cur := map[string]fileState{}
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil || !d.Type().IsRegular() {
			return err
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(dir, p)
		cur[filepath.ToSlash(rel)] = fileState{info.Size(), info.ModTime().UnixNano()}
		return nil
	})
	return cur, err
}

// upload sends everything that changed since the last successful upload, and removals, in small tarballs.
// The saved state only advances after the panel accepted a chunk, so a failed upload resumes where it stopped.
func (a *agent) upload(runID int) error {
	cur, err := scan(a.cfg.Out)
	if err != nil {
		return err
	}
	var changed, gone []string
	for p, st := range cur {
		if a.state[p] != st {
			changed = append(changed, p)
		}
	}
	for p := range a.state {
		if _, ok := cur[p]; !ok {
			gone = append(gone, p)
		}
	}
	sort.Strings(changed)
	sort.Strings(gone)
	if len(changed)+len(gone) == 0 {
		return nil
	}
	logf("uploading %d pages, %d removals", len(changed), len(gone))
	defer a.saveState()

	for i := 0; i < len(changed); {
		j, size := i, int64(0)
		for j < len(changed) && (j == i || size+cur[changed[j]].Size <= chunkBytes) {
			size += cur[changed[j]].Size
			j++
		}
		if err := a.postTar(runID, changed[i:j], nil); err != nil {
			return err
		}
		for _, p := range changed[i:j] {
			a.state[p] = cur[p]
		}
		i = j
	}
	for i := 0; i < len(gone); i += deleteChunk {
		part := gone[i:min(i+deleteChunk, len(gone))]
		if err := a.postTar(runID, nil, part); err != nil {
			return err
		}
		for _, p := range part {
			delete(a.state, p)
		}
	}
	return nil
}

func (a *agent) postTar(runID int, files, removed []string) error {
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for _, rel := range files {
		data, err := os.ReadFile(filepath.Join(a.cfg.Out, filepath.FromSlash(rel)))
		if err != nil {
			return err
		}
		if err := writeEntry(tw, rel, data); err != nil {
			return err
		}
	}
	if len(removed) > 0 {
		if err := writeEntry(tw, deletedList, []byte(strings.Join(removed, "\n"))); err != nil {
			return err
		}
	}
	if err := tw.Close(); err != nil {
		return err
	}
	if err := gz.Close(); err != nil {
		return err
	}
	return a.api("POST", fmt.Sprintf("/api/v2/sync/runs/%d/files", runID), buf.Bytes(), "application/gzip", nil)
}

func writeEntry(tw *tar.Writer, name string, data []byte) error {
	if err := tw.WriteHeader(&tar.Header{Name: name, Mode: 0o644, Size: int64(len(data))}); err != nil {
		return err
	}
	_, err := tw.Write(data)
	return err
}
