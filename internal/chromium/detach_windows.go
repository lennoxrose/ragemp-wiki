package chromium

import (
	"os/exec"
	"syscall"
)

const (
	detachedProcess    = 0x00000008
	newProcessGroup    = 0x00000200
	createNoWindowFlag = 0x08000000
)

// detach lets the browser outlive this process; hidden also suppresses any console window.
func detach(cmd *exec.Cmd, hidden bool) {
	flags := uint32(detachedProcess | newProcessGroup)
	if hidden {
		flags |= createNoWindowFlag
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: flags, HideWindow: hidden}
}
