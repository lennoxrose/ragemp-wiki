package pipeline

import (
	"fmt"

	"ragemp-wiki/internal/content"
	"ragemp-wiki/internal/convert"
	"ragemp-wiki/internal/listing"
	"ragemp-wiki/internal/manifest"
	"ragemp-wiki/internal/store"
)

// syncPages loads changed pages in batches and returns how many batches failed.
func syncPages(o Options, m *manifest.Manifest, p content.Poster, pages []listing.Page) (failed int) {
	for i := 0; i < len(pages); i += o.Batch {
		batch := pages[i:min(i+o.Batch, len(pages))]
		titles := make([]string, len(batch))
		for j, pg := range batch {
			titles[j] = pg.Title
		}
		o.Rep.Batch(i/o.Batch, len(batch), titles)
		if err := syncBatch(o, m, p, batch); err != nil {
			failed++
			o.Rep.Warn(fmt.Sprintf("batch at %d failed: %v", i, err))
		}
		o.Rep.Progress(i+len(batch), len(pages))
		if (i/o.Batch)%10 == 9 {
			_ = m.Save() // checkpoint so an interrupted run resumes
		}
	}
	return failed
}

func syncBatch(o Options, m *manifest.Manifest, p content.Poster, batch []listing.Page) error {
	titles := make([]string, len(batch))
	for i, pg := range batch {
		titles[i] = pg.Title
	}
	docs, err := content.Load(p, titles)
	if err != nil {
		return err
	}
	for _, pg := range batch {
		d, ok := docs[pg.Title]
		if !ok {
			continue // deleted since the listing
		}
		res, err := convert.Page(d.HTML, d.Categories)
		if err != nil {
			return fmt.Errorf("%s: %w", pg.Title, err)
		}
		rel := store.RelPath(pg.Title, res.Categories)
		if old, ok := m.Get(pg.Title); ok && old.Path != rel {
			store.Remove(o.Out, old.Path) // category changed, file moved
		}
		if err := store.Write(o.Out, rel, pg, res.Categories, res.Markdown); err != nil {
			return err
		}
		o.Rep.Page(pg.Title, rel)
		m.Set(pg.Title, manifest.Entry{PageID: pg.ID, RevID: pg.RevID, Path: rel,
			Categories: res.Categories, Summary: convert.Summary(res.Markdown)})
	}
	return nil
}
