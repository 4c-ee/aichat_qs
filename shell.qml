import QtQuick
import Quickshell
import Quickshell.Io
import "src"

ShellRoot {
    id: root

    property bool panelTransitionActive: false
    property bool closingPanel: false

    function togglePanel() {
        if (root.panelTransitionActive)
            return false;

        root.panelTransitionActive = true;

        if (mainPanel.opened) {
            root.closingPanel = true;
            if (!overlayPanel.prepareToClose())
                mainPanel.opened = false;
        } else {
            root.closingPanel = false;
            mainPanel.opened = true;
        }

        return true;
    }

    function openPanel() {
        if (root.panelTransitionActive)
            return false;

        root.panelTransitionActive = true;
        root.closingPanel = false;
        mainPanel.opened = true;
        return true;
    }

    function handleOverlayClosed() {
        if (root.panelTransitionActive && root.closingPanel)
            mainPanel.opened = false;
    }

    function handlePanelSlideFinished(opened) {
        if (!root.panelTransitionActive)
            return;

        if (opened)
            overlayPanel.restoreAfterPanelOpen();

        root.panelTransitionActive = false;
    }

    MainPanel {
        id: mainPanel

        onSettingsPanelRequested: {
            if (!root.panelTransitionActive)
                overlayPanel.openSettings();
        }
        onChatListPanelRequested: {
            if (!root.panelTransitionActive)
                overlayPanel.openChatList();
        }
    }

    OverlayPanel {
        id: overlayPanel
        config: mainPanel.panelConfig
        settings: mainPanel.settingsStore
        sessionsModel: mainPanel.sessionsModelValue
        sessionManager: mainPanel.sessionManager
        computeCurrentPersonaFn: mainPanel.computeCurrentPersona
        generateIdFn: mainPanel.generateId
        currentSessionId: mainPanel.currentSessionId
        panelOpened: mainPanel.opened

        onLoadSessionRequested: (id) => mainPanel.loadSession(id)
        onNewChatRequested: mainPanel.createNewSession()
        onUpdateSessionsModelRequested: mainPanel.updateSessionsModel()
    }

    Connections {
        target: mainPanel

        function onSlideFinished(opened) {
            root.handlePanelSlideFinished(opened);
        }
    }

    Connections {
        target: overlayPanel

        function onActiveViewClosed() {
            root.handleOverlayClosed();
        }
    }

    IpcHandler {
        function toggle() {
            root.togglePanel();
        }

        function openSettings() {
            if (root.panelTransitionActive)
                return;

            if (mainPanel.opened) {
                overlayPanel.openSettings();
                return;
            }

            if (root.openPanel())
                overlayPanel.requestViewAfterPanelOpen("settings");
        }

        target: "chat"
    }

}
