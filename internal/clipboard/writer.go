package clipboard

import (
	"bytes"
	"fmt"
	"os/exec"
)

type SystemWriter struct{}

func (SystemWriter) CopyImage(mimeType string, contents []byte) error {
	command := exec.Command("wl-copy", "--type", mimeType)
	command.Stdin = bytes.NewReader(contents)
	if output, err := command.CombinedOutput(); err != nil {
		return fmt.Errorf("copy clipboard image: %s", errorMessage(output, err))
	}
	return nil
}

func errorMessage(output []byte, err error) string {
	if message := string(bytes.TrimSpace(output)); message != "" {
		return message
	}
	return err.Error()
}
