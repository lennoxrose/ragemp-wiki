//go:build !windows

package chromium

import (
	"os/exec"
	"syscall"
)

func detach(cmd *exec.Cmd, _ bool) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
}
