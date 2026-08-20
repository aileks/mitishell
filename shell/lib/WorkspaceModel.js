function idsForMonitor(workspaces, monitorName) {
    return workspaces
        .filter(function(workspace) {
            return workspace.id > 0
                && workspace.monitor !== null
                && workspace.monitor.name === monitorName;
        })
        .map(function(workspace) {
            return workspace.id;
        })
        .sort(function(left, right) {
            return left - right;
        });
}

function label(id) {
    return id === 10 ? "0" : String(id);
}

if (typeof module !== "undefined") {
    module.exports = { idsForMonitor, label };
}
