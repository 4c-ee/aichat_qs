import QtQuick
import Quickshell.Io
import "MessageFormatter.js" as MessageFormatter

QtObject {
    id: root

    // Probed system information, populated by fetch().
    property var systemInfoMap: ({})
    property bool systemInfoReady: false

    signal fetched()

    function fetch() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        proc.command = ["sh", "-c", "echo 'DATE:' $(date '+%A, %B %d, %I:%M %p'); echo 'USER:' $USER; echo 'HOSTNAME:' $HOSTNAME; uname -r | sed 's/^/KERNEL: /'; cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | sed 's/\"//g' | sed 's/^/OS: /'; echo $XDG_CURRENT_DESKTOP | grep -v '^$' | sed 's/^/DE: /'"];

        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
        proc.stdout = collector;

        collector.streamFinished.connect(function() {
            var lines = collector.text.split('\n');
            var info = {};
            lines.forEach(function(line) {
                // Split on the first colon only so values containing colons
                // (e.g. a verbose time like "Sunday, November 22, 07:15 AM")
                // survive intact instead of being truncated at "07".
                var colonIdx = line.indexOf(':');
                if (colonIdx !== -1) {
                    var key = line.substring(0, colonIdx).trim();
                    var value = line.substring(colonIdx + 1).trim();
                    if (key && value) info[key] = value;
                }
            });

            var infoParts = [];
            if (info.DATE) infoParts.push("Current Date/Time: " + info.DATE);
            if (info.USER) infoParts.push("User: " + info.USER);
            if (info.HOSTNAME) infoParts.push("Hostname: " + info.HOSTNAME);
            if (info.OS) infoParts.push("OS: " + info.OS);
            if (info.DE) infoParts.push("Desktop Environment: " + info.DE);
            if (info.KERNEL) infoParts.push("Kernel: " + info.KERNEL);

            root.systemInfoMap = info;
            root.systemInfoReady = true;

            root.fetched();
            proc.destroy();
        });

        proc.running = true;
    }

    function resolveSystemPrompt(systemText) {
        if (!systemText) return "";
        var text = systemText;
        var info = root.systemInfoMap || {};

        var dateVal = info.DATE || "";
        var userVal = info.USER || "";
        var hostVal = info.HOSTNAME || "";
        var osVal = info.OS || "";
        var deVal = info.DE || "N/A";
        var kernelVal = info.KERNEL || "";

        text = text.replace(/\{date time\}/gi, dateVal)
                   .replace(/\{datetime\}/gi, dateVal)
                   .replace(/\{date\}/gi, dateVal)
                   .replace(/\{user\}/gi, userVal)
                   .replace(/\{hostname\}/gi, hostVal)
                   .replace(/\{os\}/gi, osVal)
                   .replace(/\{de\}/gi, deVal)
                   .replace(/\{desktop\}/gi, deVal)
                   .replace(/\{kernel\}/gi, kernelVal);

        return MessageFormatter.stripLegacyToolInstructions(text);
    }
}
