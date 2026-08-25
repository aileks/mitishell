// Bluetooth page presentation transforms.

function deviceStatus(device) {
    if (device.connected) {
        return "Connected";
    }
    if (device.paired) {
        return "Paired";
    }
    return device.inRange ? "Discovered" : "Known";
}

// The row actions offered for a device, in order.
function deviceActions(device) {
    const actions = [];
    if (device.connected) {
        actions.push("disconnect");
    } else if (device.paired) {
        actions.push("connect");
    } else {
        actions.push("pair");
    }
    if (device.paired) {
        actions.push(device.trusted ? "untrust" : "trust");
        actions.push("forget");
    }
    return actions;
}

// UI copy says "forget" while BlueZ's private action uses "remove".
function actionVerb(action) {
    return action === "forget" ? "remove" : action;
}

function pairPromptLabel(request) {
    switch (request.kind) {
    case "confirm":
        return "Confirm the passkey " + request.passkey + " on " + request.device;
    case "authorize":
        return request.service !== undefined && request.service !== ""
            ? "Allow " + request.device + " to use " + request.service
            : "Allow " + request.device + " to connect";
    case "passkey":
        return "Enter the passkey shown on " + request.device;
    case "pin":
        return "Enter the PIN shown on " + request.device;
    case "display-passkey":
        return "Type " + request.passkey + " on " + request.device;
    case "display-pin":
        return "Type " + request.pin + " on " + request.device;
    default:
        return "Pairing with " + request.device;
    }
}

// Display-only requests clear themselves; the others wait for an answer.
function requestIsDisplayOnly(request) {
    return request.kind === "display-passkey" || request.kind === "display-pin";
}

function requestWantsText(request) {
    return request.kind === "passkey" || request.kind === "pin";
}

if (typeof module !== "undefined") {
    module.exports = {
        deviceStatus,
        deviceActions,
        actionVerb,
        pairPromptLabel,
        requestIsDisplayOnly,
        requestWantsText,
    };
}
