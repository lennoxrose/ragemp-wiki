// Command chromiumdll builds wikisync-chromium.dll (go build -buildmode=c-shared).
// It exports the browser tools so wikisync.exe can call them without the Go
// launcher code being linked in. Every function returns a JSON string that the
// caller must release with WikiFree.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"unsafe"

	"ragemp-wiki/internal/chromium"
)

func reply(v any) *C.char {
	b, _ := json.Marshal(v)
	return C.CString(string(b))
}

func fail(err error) *C.char { return reply(map[string]any{"ok": false, "error": err.Error()}) }

// WikiChromiumStart starts (or reuses) the headless browser on the given debug port.
// userAgent may be empty, in which case it is derived from the browser version.
//
//export WikiChromiumStart
func WikiChromiumStart(port C.int, show C.int, userAgent *C.char) *C.char {
	info, started, err := chromium.Start(chromium.Options{
		Port: int(port), Show: show != 0, UserAgent: C.GoString(userAgent), URL: "https://wiki.rage.mp/wiki/Main_Page",
	})
	if err != nil {
		return fail(err)
	}
	return reply(map[string]any{"ok": true, "started": started, "browser": info.Browser, "ws": info.WebSocketDebuggerURL})
}

// WikiChromiumShutdown asks the browser on the debug port to quit.
//
//export WikiChromiumShutdown
func WikiChromiumShutdown(port C.int) *C.char {
	if err := chromium.Shutdown(int(port)); err != nil {
		return fail(err)
	}
	return reply(map[string]any{"ok": true})
}

// WikiChromiumFind reports which browser executable would be used.
//
//export WikiChromiumFind
func WikiChromiumFind() *C.char {
	exe, err := chromium.Find()
	if err != nil {
		return fail(err)
	}
	return reply(map[string]any{"ok": true, "path": exe})
}

// WikiFree releases a string returned by any other export.
//
//export WikiFree
func WikiFree(p *C.char) { C.free(unsafe.Pointer(p)) }

func main() {}
