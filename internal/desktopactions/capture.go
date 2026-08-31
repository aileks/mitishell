package desktopactions

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

var errSelectionCancelled = errors.New("selection cancelled")

func takeScreenshot(ctx context.Context, mode string, output string) error {
	directory, err := screenshotDirectory(ctx)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(directory, 0o755); err != nil {
		return fmt.Errorf("create screenshot directory: %w", err)
	}
	path := filepath.Join(directory, time.Now().Format("2006-01-02_15-04-05")+".png")
	grimArgs, err := screenshotArguments(ctx, mode, path, output)
	if errors.Is(err, errSelectionCancelled) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := runCommand(ctx, nil, "grim", grimArgs...); err != nil {
		return fmt.Errorf("take screenshot: %w", err)
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read screenshot: %w", err)
	}
	if err := runCommand(ctx, bytes.NewReader(contents), "wl-copy", "--type", "image/png"); err != nil {
		return fmt.Errorf("copy screenshot: %w", err)
	}
	return showScreenshotNotification(path)
}

// showScreenshotNotification reports the saved screenshot and offers
// annotation. The notifier waits for the popup to close, so it runs
// detached: the action must not stay busy for the popup's lifetime or the
// launcher cannot start another capture.
func showScreenshotNotification(path string) error {
	quoted := shellQuote(path)
	title := "'Screenshot saved and copied' " + quoted
	script := "notify-send -a Screenshot -i " + quoted + " " + title
	if _, err := exec.LookPath("tensaku"); err == nil {
		script = "out=$(notify-send -a Screenshot -i " + quoted +
			" -A annotate=Annotate " + title + ")" +
			" && [ \"$out\" = annotate ] && exec tensaku" +
			" --filename " + quoted +
			" --output-filename " + quoted +
			" --copy-command wl-copy" +
			" --app-id dev.tensaku.Tensaku" +
			" --actions-on-enter save-to-file" +
			" --actions-on-enter save-to-clipboard" +
			" --actions-on-enter exit"
	}
	command := exec.Command("sh", "-c", script)
	return detachCommand(command)
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func detachCommand(command *exec.Cmd) error {
	command.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	devNull, err := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if err != nil {
		return fmt.Errorf("open null device: %w", err)
	}
	defer devNull.Close()
	command.Stdin = devNull
	command.Stdout = devNull
	command.Stderr = devNull
	if err := command.Start(); err != nil {
		return fmt.Errorf("start notification: %w", err)
	}
	return command.Process.Release()
}

func screenshotArguments(ctx context.Context, mode string, path string, output string) ([]string, error) {
	switch mode {
	case "output":
		if output == "" {
			return nil, fmt.Errorf("invalid screenshot output")
		}
		return []string{"-o", output, path}, nil
	case "window":
		geometry, err := activeWindowGeometry(ctx)
		if err != nil {
			return nil, err
		}
		return []string{"-g", geometry, path}, nil
	case "region":
		geometry, err := selectRegion(ctx, "")
		if err != nil {
			return nil, err
		}
		return []string{"-g", geometry, path}, nil
	default:
		return nil, fmt.Errorf("invalid screenshot mode %q", mode)
	}
}

func extractText(ctx context.Context) error {
	geometry, err := selectRegion(ctx, "")
	if errors.Is(err, errSelectionCancelled) {
		return nil
	}
	if err != nil {
		return err
	}
	image, err := commandOutput(ctx, nil, "grim", "-g", geometry, "-")
	if err != nil {
		return fmt.Errorf("capture text region: %w", err)
	}
	result, err := commandOutput(ctx, bytes.NewReader(image), "tesseract",
		"stdin", "stdout",
		"--oem", "1",
		"--psm", "6",
		"-l", "eng",
		"--dpi", "300",
		"-c", "preserve_interword_spaces=1",
	)
	if err != nil || strings.TrimSpace(string(result)) == "" {
		_ = notify(ctx, "critical", "Text Extraction", "No text found")
		if err != nil {
			return fmt.Errorf("extract text: %w", err)
		}
		return fmt.Errorf("extract text: no text found")
	}
	if err := runCommand(ctx, bytes.NewReader(result), "wl-copy"); err != nil {
		return fmt.Errorf("copy extracted text: %w", err)
	}
	return notify(ctx, "", "Text Extraction", "Text copied")
}

func scanQR(ctx context.Context) error {
	geometry, err := selectRegion(ctx, "")
	if errors.Is(err, errSelectionCancelled) {
		return nil
	}
	if err != nil {
		return err
	}
	image, err := commandOutput(ctx, nil, "grim", "-g", geometry, "-")
	if err != nil {
		return fmt.Errorf("capture QR region: %w", err)
	}
	result, err := commandOutput(ctx, bytes.NewReader(image), "zbarimg",
		"-q", "--raw", "-Sdisable", "-Sqrcode.enable", "-")
	if err != nil || strings.TrimSpace(string(result)) == "" {
		_ = notify(ctx, "critical", "QR Capture", "No QR code found")
		if err != nil {
			return fmt.Errorf("scan QR code: %w", err)
		}
		return fmt.Errorf("scan QR code: no QR code found")
	}
	if err := runCommand(ctx, bytes.NewReader(bytes.TrimSpace(result)),
		"wl-copy", "--sensitive"); err != nil {
		return fmt.Errorf("copy QR code: %w", err)
	}
	return notify(ctx, "", "QR Capture", "QR code copied")
}

func selectRegion(ctx context.Context, format string) (string, error) {
	freeze := exec.CommandContext(ctx, "hyprpicker", "-r", "-z")
	freeze.Stdout = io.Discard
	freeze.Stderr = io.Discard
	if err := freeze.Start(); err != nil {
		return "", fmt.Errorf("freeze screen: %w", err)
	}
	defer func() {
		_ = freeze.Process.Kill()
		_ = freeze.Wait()
	}()

	timer := time.NewTimer(100 * time.Millisecond)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case <-timer.C:
	}
	args := []string{}
	if format != "" {
		args = append(args, "-f", format)
	}
	geometry, err := commandOutput(ctx, nil, "slurp", args...)
	if err != nil {
		return "", errSelectionCancelled
	}
	value := strings.TrimSpace(string(geometry))
	if value == "" {
		return "", errSelectionCancelled
	}
	return value, nil
}

// focusedOutput names the output the pointer is on; recordings capture it
// when no explicit output is chosen.
func focusedOutput(ctx context.Context) (string, error) {
	output, err := commandOutput(ctx, nil, "hyprctl", "-j", "monitors")
	if err != nil {
		return "", fmt.Errorf("read monitors: %w", err)
	}
	var monitors []struct {
		Name    string
		Focused bool
	}
	if err := json.Unmarshal(output, &monitors); err != nil {
		return "", fmt.Errorf("decode monitors: %w", err)
	}
	for _, monitor := range monitors {
		if monitor.Focused && monitor.Name != "" {
			return monitor.Name, nil
		}
	}
	return "", fmt.Errorf("could not determine the focused output")
}

func activeWindowGeometry(ctx context.Context) (string, error) {
	output, err := commandOutput(ctx, nil, "hyprctl", "-j", "activewindow")
	if err != nil {
		return "", fmt.Errorf("read active window: %w", err)
	}
	var window struct {
		At   []int
		Size []int
	}
	if err := json.Unmarshal(output, &window); err != nil {
		return "", fmt.Errorf("decode active window: %w", err)
	}
	if len(window.At) != 2 || len(window.Size) != 2 || window.Size[0] <= 0 || window.Size[1] <= 0 {
		return "", fmt.Errorf("could not determine the active window")
	}
	return fmt.Sprintf("%d,%d %dx%d", window.At[0], window.At[1], window.Size[0], window.Size[1]), nil
}

func screenshotDirectory(ctx context.Context) (string, error) {
	if output, err := commandOutput(ctx, nil, "xdg-user-dir", "PICTURES"); err == nil {
		if directory := strings.TrimSpace(string(output)); directory != "" {
			return filepath.Join(directory, "Screenshots"), nil
		}
	}
	if directory := strings.TrimSpace(os.Getenv("XDG_PICTURES_DIR")); directory != "" {
		return filepath.Join(directory, "Screenshots"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve pictures directory: %w", err)
	}
	return filepath.Join(home, "Pictures", "Screenshots"), nil
}

func notify(ctx context.Context, urgency string, application string, message string) error {
	if _, err := exec.LookPath("notify-send"); err != nil {
		return fmt.Errorf("Please install libnotify for desktop notifications")
	}
	args := []string{"-a", application}
	if urgency != "" {
		args = append(args, "-u", urgency)
	}
	args = append(args, message)
	if err := runCommand(ctx, nil, "notify-send", args...); err != nil {
		return fmt.Errorf("show notification: %w", err)
	}
	return nil
}

// runCommand runs a side-effect command and discards its output on files
// rather than pipes: helper tools such as wl-copy fork a long-lived server
// that would inherit pipe ends and block Wait long after the command exits.
func runCommand(ctx context.Context, stdin io.Reader, name string, args ...string) error {
	devNull, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
	if err != nil {
		return fmt.Errorf("open null device: %w", err)
	}
	defer devNull.Close()
	stderr, err := os.CreateTemp("", "mitishell-stderr-*")
	if err != nil {
		return fmt.Errorf("create stderr capture: %w", err)
	}
	defer func() {
		stderr.Close()
		os.Remove(stderr.Name())
	}()

	command := exec.CommandContext(ctx, name, args...)
	command.Stdin = stdin
	command.Stdout = devNull
	command.Stderr = stderr
	if err := command.Run(); err != nil {
		contents, _ := os.ReadFile(stderr.Name())
		message := strings.TrimSpace(string(contents))
		if message == "" {
			message = err.Error()
		}
		return errors.New(message)
	}
	return nil
}

func commandOutput(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
	command := exec.CommandContext(ctx, name, args...)
	command.Stdin = stdin
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	command.Stdout = &stdout
	command.Stderr = &stderr
	if err := command.Run(); err != nil {
		message := strings.TrimSpace(stderr.String())
		if message == "" {
			message = err.Error()
		}
		return nil, errors.New(message)
	}
	return stdout.Bytes(), nil
}
