package bluetooth

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"

	"github.com/aileks/mitishell/internal/ipc"
)

// The BlueZ Agent1 adapter. Pairing requests arrive on the agent interface
// while the shell is showing the Bluetooth page; each request is forwarded
// into the shell through QuickShell IPC and the answer comes back over the
// control interface from the one-shot _bluetooth-respond verb.

const (
	agentPath        = "/io/github/aileks/mitishell/agent"
	agentFace        = "org.bluez.Agent1"
	agentManager     = "org.bluez.AgentManager1"
	agentManagerPath = "/org/bluez"
	requestTimeout   = 2 * time.Minute
)

// PairRequest is the payload pushed to the shell.
type PairRequest struct {
	Id      string `json:"id"`
	Kind    string `json:"kind"`
	Device  string `json:"device"`
	Passkey string `json:"passkey,omitempty"`
	Pin     string `json:"pin,omitempty"`
	Entered int    `json:"entered,omitempty"`
	Service string `json:"service,omitempty"`
}

type agentResponse struct {
	kind  string
	value string
}

type ShellNotifier interface {
	PairRequest(payload string) error
}

type qsNotifier struct {
	client ipc.Client
}

func (notifier qsNotifier) PairRequest(payload string) error {
	_, err := notifier.client.Call("bluetooth", "pairRequest", payload)
	return err
}

// RunAgent registers a KeyboardDisplay agent and serves pairing requests
// until the context ends, then unregisters.
func RunAgent(ctx context.Context) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	qsExecutable := os.Getenv("MITISHELL_QS_BIN")
	if qsExecutable == "" {
		qsExecutable = "qs"
	}
	shellPath, err := ipc.ResolveShellPath()
	if err != nil {
		return err
	}

	agent := &pairingAgent{
		pending: map[string]chan agentResponse{},
		notify:  qsNotifier{client: ipc.NewClient(qsExecutable, shellPath)},
	}

	if err := conn.Export(agent, agentPath, agentFace); err != nil {
		return err
	}
	if err := conn.Export(&agentControl{agent: agent}, controlPath, controlFace); err != nil {
		return err
	}
	if reply, err := conn.RequestName(controlName, dbus.NameFlagDoNotQueue); err != nil {
		return err
	} else if reply != dbus.RequestNameReplyPrimaryOwner {
		return fmt.Errorf("another mitishell bluetooth agent is running")
	}

	manager := conn.Object(bluezName, agentManagerPath)
	if err := manager.Call(agentManager+".RegisterAgent", 0,
		agentPath, "KeyboardDisplay").Err; err != nil {
		return fmt.Errorf("register agent: %w", err)
	}
	if err := manager.Call(agentManager+".RequestDefaultAgent", 0, agentPath).Err; err != nil {
		// Still usable when only registered, not default.
		_ = err
	}
	defer manager.Call(agentManager+".UnregisterAgent", 0, agentPath)

	<-ctx.Done()
	agent.cancelAll()
	return nil
}

type pairingAgent struct {
	mutex   sync.Mutex
	pending map[string]chan agentResponse
	notify  ShellNotifier
}

// ask forwards a request to the shell and waits for the response.
func (agent *pairingAgent) ask(request PairRequest) (agentResponse, *dbus.Error) {
	request.Id = fmt.Sprintf("%d", time.Now().UnixNano())
	encoded, err := json.Marshal(request)
	if err != nil {
		return agentResponse{}, dbus.MakeFailedError(err)
	}
	if err := agent.notify.PairRequest(string(encoded)); err != nil {
		return agentResponse{}, dbus.MakeFailedError(fmt.Errorf("shell unreachable: %w", err))
	}

	responses := make(chan agentResponse, 1)
	agent.mutex.Lock()
	agent.pending[request.Id] = responses
	agent.mutex.Unlock()

	select {
	case response := <-responses:
		if response.kind == "cancel" {
			return agentResponse{}, dbus.MakeFailedError(fmt.Errorf("cancelled"))
		}
		return response, nil
	case <-time.After(requestTimeout):
		agent.mutex.Lock()
		delete(agent.pending, request.Id)
		agent.mutex.Unlock()
		return agentResponse{}, dbus.MakeFailedError(fmt.Errorf("pairing request timed out"))
	}
}

// show forwards a display-only request; no answer is expected.
func (agent *pairingAgent) show(request PairRequest) {
	request.Id = fmt.Sprintf("%d", time.Now().UnixNano())
	encoded, err := json.Marshal(request)
	if err != nil {
		return
	}
	_ = agent.notify.PairRequest(string(encoded))
}

func (agent *pairingAgent) cancelAll() {
	agent.mutex.Lock()
	defer agent.mutex.Unlock()
	for _, responses := range agent.pending {
		select {
		case responses <- agentResponse{kind: "cancel"}:
		default:
		}
	}
	agent.pending = map[string]chan agentResponse{}
}

func (agent *pairingAgent) Release() *dbus.Error {
	return nil
}

func (agent *pairingAgent) RequestPinCode(device dbus.ObjectPath) (string, *dbus.Error) {
	response, err := agent.ask(PairRequest{Kind: "pin", Device: deviceAddress(device)})
	if err != nil {
		return "", err
	}
	return response.value, nil
}

func (agent *pairingAgent) DisplayPinCode(device dbus.ObjectPath, pin string) *dbus.Error {
	agent.show(PairRequest{Kind: "display-pin", Device: deviceAddress(device), Pin: pin})
	return nil
}

func (agent *pairingAgent) RequestPasskey(device dbus.ObjectPath) (uint32, *dbus.Error) {
	response, err := agent.ask(PairRequest{Kind: "passkey", Device: deviceAddress(device)})
	if err != nil {
		return 0, err
	}
	passkey, parseErr := strconv.ParseUint(response.value, 10, 32)
	if parseErr != nil {
		return 0, dbus.MakeFailedError(parseErr)
	}
	return uint32(passkey), nil
}

func (agent *pairingAgent) DisplayPasskey(device dbus.ObjectPath, passkey uint32, entered uint16) *dbus.Error {
	agent.show(PairRequest{
		Kind:    "display-passkey",
		Device:  deviceAddress(device),
		Passkey: fmt.Sprintf("%06d", passkey),
		Entered: int(entered),
	})
	return nil
}

func (agent *pairingAgent) RequestConfirmation(device dbus.ObjectPath, passkey uint32) *dbus.Error {
	response, err := agent.ask(PairRequest{
		Kind:    "confirm",
		Device:  deviceAddress(device),
		Passkey: fmt.Sprintf("%06d", passkey),
	})
	if err != nil {
		return err
	}
	if response.value != "true" {
		return dbus.MakeFailedError(fmt.Errorf("rejected"))
	}
	return nil
}

func (agent *pairingAgent) RequestAuthorization(device dbus.ObjectPath) *dbus.Error {
	return agent.confirmGeneric(PairRequest{Kind: "authorize", Device: deviceAddress(device)})
}

func (agent *pairingAgent) AuthorizeService(device dbus.ObjectPath, uuid string) *dbus.Error {
	return agent.confirmGeneric(PairRequest{
		Kind:    "authorize",
		Device:  deviceAddress(device),
		Service: uuid,
	})
}

func (agent *pairingAgent) confirmGeneric(request PairRequest) *dbus.Error {
	response, err := agent.ask(request)
	if err != nil {
		return err
	}
	if response.value != "true" {
		return dbus.MakeFailedError(fmt.Errorf("rejected"))
	}
	return nil
}

func (agent *pairingAgent) Cancel() *dbus.Error {
	agent.cancelAll()
	return nil
}

type agentControl struct {
	agent *pairingAgent
}

// Respond answers a pending pairing request; the value carries a passkey,
// PIN, "true", "false", or "cancel".
func (control *agentControl) Respond(id string, value string) *dbus.Error {
	control.agent.mutex.Lock()
	responses, ok := control.agent.pending[id]
	if ok {
		delete(control.agent.pending, id)
	}
	control.agent.mutex.Unlock()
	if !ok {
		return dbus.MakeFailedError(fmt.Errorf("no pending request %q", id))
	}
	responses <- agentResponse{value: value}
	return nil
}

// deviceAddress turns a BlueZ device path into its MAC-style address.
func deviceAddress(path dbus.ObjectPath) string {
	_, suffix, found := strings.Cut(string(path), "/dev_")
	if !found {
		return string(path)
	}
	return strings.ToUpper(strings.ReplaceAll(suffix, "_", ":"))
}

// Respond answers a pending pairing request from a one-shot process.
func Respond(id string, value string) error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	object := conn.Object(controlName, controlPath)
	call := object.Call(controlFace+".Respond", 0, id, value)
	if call.Err != nil {
		return call.Err
	}
	return nil
}
