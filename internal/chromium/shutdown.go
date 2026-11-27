package chromium

import (
	"fmt"

	"golang.org/x/net/websocket"
)

// Shutdown asks the browser on the debug port to quit (CDP Browser.close).
func Shutdown(port int) error {
	info, ok := Probe(port)
	if !ok {
		return nil // nothing running
	}
	ws, err := websocket.Dial(info.WebSocketDebuggerURL, "", fmt.Sprintf("http://127.0.0.1:%d", port))
	if err != nil {
		return err
	}
	defer ws.Close()
	return websocket.Message.Send(ws, `{"id":1,"method":"Browser.close"}`)
}
