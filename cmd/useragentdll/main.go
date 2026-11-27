// Command useragentdll builds wikisync-useragent.dll (go build -buildmode=c-shared).
// It exports the User-Agent builder; every export returns a JSON string that the
// caller must release with WikiFree.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"unsafe"

	"ragemp-wiki/internal/useragent"
)

// WikiUserAgent returns the normal-Chrome User-Agent for a browser executable path.
//
//export WikiUserAgent
func WikiUserAgent(exe *C.char) *C.char {
	b, _ := json.Marshal(map[string]any{"ok": true, "userAgent": useragent.For(C.GoString(exe))})
	return C.CString(string(b))
}

// WikiFree releases a string returned by WikiUserAgent.
//
//export WikiFree
func WikiFree(p *C.char) { C.free(unsafe.Pointer(p)) }

func main() {}
