// Package manifest remembers which revision of each page is on disk, so reruns
// only touch pages that changed, appeared or were deleted.
package manifest

import (
	"encoding/json"
	"os"
	"sync"

	"ragemp-wiki/internal/listing"
)

type Entry struct {
	PageID     int      `json:"pageid"`
	RevID      int      `json:"revid"`
	Path       string   `json:"path"` // relative to the output dir, slash separated
	Categories []string `json:"categories"`
	Summary    string   `json:"summary"`
}

type Manifest struct {
	mu      sync.Mutex
	file    string
	Entries map[string]Entry `json:"entries"` // keyed by page title
}

func Load(file string) (*Manifest, error) {
	m := &Manifest{file: file, Entries: map[string]Entry{}}
	b, err := os.ReadFile(file)
	if os.IsNotExist(err) {
		return m, nil
	}
	if err != nil {
		return nil, err
	}
	return m, json.Unmarshal(b, m)
}

// Diff splits the live listing into pages to (re)fetch and titles to delete.
func (m *Manifest) Diff(live []listing.Page) (changed []listing.Page, removed []string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	seen := make(map[string]bool, len(live))
	for _, p := range live {
		seen[p.Title] = true
		if e, ok := m.Entries[p.Title]; !ok || e.RevID != p.RevID {
			changed = append(changed, p)
		}
	}
	for title := range m.Entries {
		if !seen[title] {
			removed = append(removed, title)
		}
	}
	return changed, removed
}

func (m *Manifest) Get(title string) (Entry, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.Entries[title]
	return e, ok
}

func (m *Manifest) Set(title string, e Entry) {
	m.mu.Lock()
	m.Entries[title] = e
	m.mu.Unlock()
}

func (m *Manifest) Delete(title string) {
	m.mu.Lock()
	delete(m.Entries, title)
	m.mu.Unlock()
}

func (m *Manifest) Save() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	b, err := json.Marshal(m)
	if err != nil {
		return err
	}
	tmp := m.file + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, m.file)
}
