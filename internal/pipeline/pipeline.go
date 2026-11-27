// Package pipeline wires listing, loading, conversion and storage together.
package pipeline

import (
	"os"
	"path/filepath"

	"ragemp-wiki/internal/browser"
	"ragemp-wiki/internal/listing"
	"ragemp-wiki/internal/manifest"
	"ragemp-wiki/internal/report"
	"ragemp-wiki/internal/store"
)

type Options struct {
	Out   string
	NS    int
	Batch int
	Port  int
	Full  bool // refetch everything regardless of the manifest
	Limit int  // 0 = no limit; handy for testing
	Mode  store.Mode
	Rep   report.Reporter
}

func Run(o Options) error {
	if err := os.MkdirAll(o.Out, 0o755); err != nil {
		return err
	}
	m, err := manifest.Load(filepath.Join(o.Out, ".manifest.json"))
	if err != nil {
		return err
	}
	o.Rep.Phase("listing")
	sess, err := browser.Connect(o.Port)
	if err != nil {
		return err
	}
	defer sess.Close()
	pages, err := listing.All(sess, o.NS, o.Rep.Listing)
	if err != nil {
		return err
	}
	changed, removed := m.Diff(pages)
	if o.Full {
		changed = pages
	}
	if o.Limit > 0 && len(changed) > o.Limit {
		changed = changed[:o.Limit]
	}
	o.Rep.Plan(len(pages), len(changed), len(removed))
	for _, t := range removed {
		if e, ok := m.Get(t); ok {
			store.Remove(o.Out, e.Path)
		}
		m.Delete(t)
	}
	o.Rep.Phase("syncing")
	failed := syncPages(o, m, sess, changed)
	o.Rep.Phase("indexing")
	if err := m.Save(); err != nil {
		return err
	}
	if err := store.WriteIndexes(o.Out, m, o.Mode); err != nil {
		return err
	}
	o.Rep.Done(failed)
	return nil
}
