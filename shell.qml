import QtQuick
import Quickshell
import Quickshell.Io
import "src"

ShellRoot {
    MainPanel {
        id: mainPanel

        onSettingsPanelRequested: overlayPanel.openSettings()
        onChatListPanelRequested: overlayPanel.openChatList()
    }

    OverlayPanel {
        id: overlayPanel
        config: mainPanel.panelConfig
        settings: mainPanel.settingsStore
        sessionsModel: mainPanel.sessionsModelValue
        generateIdFn: mainPanel.generateId
        currentSessionId: mainPanel.currentSessionId

        onLoadSessionRequested: (id) => mainPanel.loadSession(id)
        onNewChatRequested: mainPanel.createNewSession()
        onUpdateSessionsModelRequested: mainPanel.updateSessionsModel()
    }

    IpcHandler {
        function toggle() {
            mainPanel.opened = !mainPanel.opened;
        }

        function openSettings() {
            mainPanel.openSettings();
        }

        target: "chat"
    }

}
