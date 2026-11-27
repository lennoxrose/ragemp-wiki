//go:build !windows

package browser

// startViaDLL is Windows-only; other platforms use the Go code directly.
func startViaDLL(int) (bool, bool, error) { return false, false, nil }
