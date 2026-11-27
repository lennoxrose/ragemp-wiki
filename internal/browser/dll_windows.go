//go:build windows

package browser

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"unsafe"
)

// loadDLL opens a DLL that sits next to the executable; nil when it is absent.
func loadDLL(name string) *syscall.LazyDLL {
	self, err := os.Executable()
	if err != nil {
		return nil
	}
	path := filepath.Join(filepath.Dir(self), name)
	if _, err := os.Stat(path); err != nil {
		return nil
	}
	return syscall.NewLazyDLL(path)
}

// call runs one DLL export that takes C args and returns a JSON C string,
// frees that string, and decodes the JSON into v.
func call(dll *syscall.LazyDLL, fn string, v any, args ...uintptr) error {
	ptr, _, _ := dll.NewProc(fn).Call(args...)
	text := cString(ptr)
	dll.NewProc("WikiFree").Call(ptr)
	return json.Unmarshal([]byte(text), v)
}

func cArg(s string) (uintptr, *byte) {
	b, _ := syscall.BytePtrFromString(s)
	return uintptr(unsafe.Pointer(b)), b
}

type reply struct {
	OK        bool   `json:"ok"`
	Error     string `json:"error"`
	Started   bool   `json:"started"`
	Path      string `json:"path"`
	UserAgent string `json:"userAgent"`
}

func (r reply) err() error {
	if r.OK {
		return nil
	}
	return errors.New(r.Error)
}

// startViaDLL asks wikisync-useragent.dll for the User-Agent and passes it to
// wikisync-chromium.dll, which starts the browser. used is false when the
// chromium DLL is absent so the caller can fall back to the built-in code.
func startViaDLL(port int) (started bool, used bool, err error) {
	browserDLL := loadDLL("wikisync-chromium.dll")
	if browserDLL == nil {
		return false, false, nil
	}
	var ua string
	if uaDLL := loadDLL("wikisync-useragent.dll"); uaDLL != nil {
		var found, r reply
		if call(browserDLL, "WikiChromiumFind", &found) == nil && found.OK {
			arg, keep := cArg(found.Path)
			if call(uaDLL, "WikiUserAgent", &r, arg) == nil {
				ua = r.UserAgent
			}
			runtime.KeepAlive(keep)
		}
	}
	arg, keep := cArg(ua)
	var r reply
	e := call(browserDLL, "WikiChromiumStart", &r, uintptr(port), 0, arg)
	runtime.KeepAlive(keep)
	if e != nil {
		return false, true, e
	}
	return r.Started, true, r.err()
}

// cString copies a NUL-terminated string out of memory owned by a DLL.
func cString(addr uintptr) string {
	p := *(*unsafe.Pointer)(unsafe.Pointer(&addr))
	n := 0
	for *(*byte)(unsafe.Add(p, n)) != 0 {
		n++
	}
	return string(unsafe.Slice((*byte)(p), n))
}
