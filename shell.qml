import QtQuick
import Quickshell
import Quickshell.Io
import "src"

ShellRoot {
    MainPanel {
        id: mainPanel
    }

    IpcHandler {
        function toggle() {
            mainPanel.opened = !mainPanel.opened;
        }

        target: "chat"
    }

}
