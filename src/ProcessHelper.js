.pragma library

// Run a command via Quickshell.Io Process and deliver its stdout (trimmed)
// to onFinished once the stream closes. Stderr output is reported via
// console.error so failures are visible but do not crash the caller.
// `context` is the QML object used as the creation context for the
// dynamically created Process / StdioCollector objects.
function runCommand(context, command, onFinished) {
    var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', context);
    proc.command = command;

    var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
    proc.stdout = collector;

    var errCollector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
    proc.stderr = errCollector;

    errCollector.streamFinished.connect(function() {
        if (errCollector.text !== "")
            console.error("Command error:", command.join(" "), "-", errCollector.text);
    });

    collector.streamFinished.connect(function() {
        onFinished(collector.text.trim());
        proc.destroy();
    });

    proc.running = true;
}
