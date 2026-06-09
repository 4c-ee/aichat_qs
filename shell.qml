import QtQuick
import Quickshell
import Quickshell.Io
import "src"

ShellRoot {
    MainPanel {
        id: mainPanel
    }
    
    IpcHandler {
        target: "chat"
        
        function toggle(): void {
            mainPanel.opened = !mainPanel.opened;
        }
    }
}
