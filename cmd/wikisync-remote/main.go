// wikisync-remote keeps a wikisync running on this PC for the panel: it polls the panel over HTTPS for a
// queued run, runs wikisync.exe (which drives wikisync-chromium.dll) next to it, streams the progress back
// and uploads the pages it wrote. Only outbound HTTPS is used, so nothing has to be opened on this PC.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type config struct {
	Server string `json:"server"` // https://rage-wiki.example.org
	Key    string `json:"key"`    // WIKISYNC_API_KEY of the panel
	Out    string `json:"out"`    // where wikisync writes the pages
}

type agent struct {
	cfg   config
	exe   string // wikisync.exe
	dir   string // folder of this exe (also holds the DLLs and the saved state)
	http  *http.Client
	state map[string]fileState // what the panel already has
}

func main() {
	dir, _ := os.Executable()
	dir = filepath.Dir(dir)
	var cfg config
	cfgPath := filepath.Join(dir, "wikisync-remote.json")
	if b, err := os.ReadFile(cfgPath); err == nil {
		_ = json.Unmarshal(b, &cfg)
	}
	flag.StringVar(&cfg.Server, "server", cfg.Server, "panel URL, e.g. https://rage-wiki.rigkit.org")
	flag.StringVar(&cfg.Key, "key", firstNonEmpty(cfg.Key, os.Getenv("WIKISYNC_API_KEY")), "panel WIKISYNC_API_KEY")
	flag.StringVar(&cfg.Out, "out", firstNonEmpty(cfg.Out, filepath.Join(dir, "remote-dist")), "output folder for the pages")
	interval := flag.Duration("interval", 10*time.Second, "how often to ask the panel for work")
	resend := flag.Bool("resend", false, "upload every page again (use after the panel's data was wiped)")
	flag.Parse()

	in := bufio.NewReader(os.Stdin)
	if cfg.Server == "" {
		cfg.Server = ask(in, "Panel URL (e.g. https://rage-wiki.rigkit.org): ")
	}
	if cfg.Key == "" {
		cfg.Key = ask(in, "Panel WIKISYNC_API_KEY: ")
	}
	cfg.Server = strings.TrimRight(cfg.Server, "/")
	if b, err := json.MarshalIndent(cfg, "", "  "); err == nil {
		_ = os.WriteFile(cfgPath, b, 0o600)
	}

	a := &agent{cfg: cfg, exe: filepath.Join(dir, "wikisync.exe"), dir: dir, http: &http.Client{Timeout: 90 * time.Second}}
	if _, err := os.Stat(a.exe); err != nil {
		fatal("wikisync.exe must sit next to wikisync-remote.exe: " + err.Error())
	}
	a.state = loadState(a.statePath())
	if *resend {
		a.state = map[string]fileState{}
	}
	logf("connected to %s, waiting for runs (Ctrl+C to quit)", cfg.Server)
	for {
		if err := a.poll(); err != nil {
			logf("%v", err)
		}
		time.Sleep(*interval)
	}
}

func (a *agent) statePath() string { return filepath.Join(a.dir, "wikisync-remote.state.json") }

// poll asks the panel for a queued run and, when there is one, does it.
func (a *agent) poll() error {
	var cfg struct {
		Options struct {
			Batch     int `json:"batch"`
			Namespace any `json:"namespace"`
		} `json:"options"`
		Pending *struct {
			ID   int    `json:"id"`
			Full bool   `json:"full"`
			Mode string `json:"mode"`
		} `json:"pending"`
	}
	if err := a.api("GET", "/api/v2/sync/config", nil, "", &cfg); err != nil || cfg.Pending == nil {
		return err
	}
	id := cfg.Pending.ID
	if err := a.api("POST", fmt.Sprintf("/api/v2/sync/runs/%d/claim", id), nil, "", nil); err != nil {
		var he *httpError
		if errors.As(err, &he) && he.code == http.StatusConflict {
			return nil // another agent took it
		}
		return err
	}
	logf("run %d claimed (%s, full=%t)", id, cfg.Pending.Mode, cfg.Pending.Full)
	args := []string{"-json", "-out", a.cfg.Out, "-mode", cfg.Pending.Mode, "-batch", fmt.Sprint(max(cfg.Options.Batch, 1)), "-ns", fmt.Sprint(cfg.Options.Namespace)}
	if cfg.Pending.Full {
		args = append(args, "-full")
	}
	a.runOnce(id, args)
	return nil
}

// runOnce runs wikisync, forwards its events, uploads the pages, then reports the end of the run.
func (a *agent) runOnce(id int, args []string) {
	cmd := exec.Command(a.exe, args...)
	cmd.Dir = a.dir // wikisync finds the DLLs next to itself
	pipe, _ := cmd.StdoutPipe()
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		a.finish(id, "could not start wikisync.exe: "+err.Error())
		return
	}
	lines := make(chan string)
	go func() {
		sc := bufio.NewScanner(pipe)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			lines <- sc.Text()
		}
		close(lines)
	}()

	var batch []json.RawMessage
	var ended json.RawMessage // the done/error event: sent after the upload, so the panel only shows "success" once the pages are there
	cancelled := false
	flush := func() {
		if len(batch) == 0 {
			return
		}
		var resp struct {
			Run struct {
				Status string `json:"status"`
			} `json:"run"`
		}
		body, _ := json.Marshal(map[string]any{"events": batch})
		if err := a.api("POST", fmt.Sprintf("/api/v2/sync/runs/%d/events", id), body, "application/json", &resp); err != nil {
			logf("events: %v", err)
		} else if resp.Run.Status == "cancelled" && !cancelled {
			cancelled = true
			logf("run cancelled in the panel, stopping wikisync")
			_ = cmd.Process.Kill()
		}
		batch = nil
	}
	tick := time.NewTicker(2 * time.Second)
	defer tick.Stop()
loop:
	for {
		select {
		case l, ok := <-lines:
			if !ok {
				break loop
			}
			var ev struct {
				T string `json:"t"`
			}
			if json.Unmarshal([]byte(l), &ev) != nil || ev.T == "" {
				fmt.Println(l)
				continue
			}
			if ev.T == "done" || ev.T == "error" {
				ended = json.RawMessage(l)
				continue
			}
			batch = append(batch, json.RawMessage(l))
			if len(batch) >= 25 {
				flush()
			}
		case <-tick.C:
			flush()
		}
	}
	waitErr := cmd.Wait()
	flush()
	if cancelled {
		logf("run %d cancelled", id)
		return
	}

	uploadErr := a.upload(id)
	if uploadErr != nil {
		logf("upload: %v", uploadErr)
	}
	switch {
	case uploadErr != nil:
		a.finish(id, "uploading pages to the panel failed: "+uploadErr.Error())
	case ended == nil:
		a.finish(id, fmt.Sprintf("wikisync.exe exited without a result (%v)", waitErr))
	default:
		body, _ := json.Marshal(map[string]any{"events": []json.RawMessage{ended}})
		_ = a.api("POST", fmt.Sprintf("/api/v2/sync/runs/%d/events", id), body, "application/json", nil)
		a.finish(id, "")
	}
	logf("run %d finished", id)
}

func (a *agent) finish(id int, errMsg string) {
	body, _ := json.Marshal(map[string]any{"error": errMsg})
	if err := a.api("POST", fmt.Sprintf("/api/v2/sync/runs/%d/finish", id), body, "application/json", nil); err != nil {
		logf("finish: %v", err)
	}
}

type httpError struct {
	code int
	msg  string
}

func (e *httpError) Error() string { return fmt.Sprintf("panel answered %d: %s", e.code, e.msg) }

// api calls the panel; out, when set, receives the JSON response.
func (a *agent) api(method, path string, body []byte, contentType string, out any) error {
	req, err := http.NewRequest(method, a.cfg.Server+path, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+a.cfg.Key)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	resp, err := a.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode >= 300 {
		return &httpError{resp.StatusCode, strings.TrimSpace(string(data))}
	}
	if out != nil {
		return json.Unmarshal(data, out)
	}
	return nil
}

func ask(in *bufio.Reader, prompt string) string {
	fmt.Print(prompt)
	s, _ := in.ReadString('\n')
	return strings.TrimSpace(s)
}

func firstNonEmpty(v ...string) string {
	for _, s := range v {
		if s != "" {
			return s
		}
	}
	return ""
}

func logf(format string, a ...any) {
	fmt.Printf("%s  %s\n", time.Now().Format("15:04:05"), fmt.Sprintf(format, a...))
}

func fatal(msg string) {
	fmt.Fprintln(os.Stderr, "error:", msg)
	os.Exit(1)
}
