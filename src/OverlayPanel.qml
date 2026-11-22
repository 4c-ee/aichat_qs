import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var config
    property var settings
    property var sessionsModel
    property var sessionManager
    property var computeCurrentPersonaFn
    property var generateIdFn
    property string currentSessionId
    property bool settingsActive: false
    property bool panelOpened: true
    property string viewToRestore: "none"

    signal loadSessionRequested(string id)
    signal newChatRequested()
    signal updateSessionsModelRequested()
    signal activeViewClosed()

    anchors {
        left: true
        top: true
        bottom: true
    }

    implicitWidth: config ? config.panelWidth : 500
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aichat_qs"
    WlrLayershell.keyboardFocus: (root.panelOpened && (settingsActive || chatList.isOpen))
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand
    exclusiveZone: 0

    function openSettings() {
        chatList.close();
        root.settingsActive = true;
        settingsPopup.open();
    }

    // Persist any unsaved settings draft before the panel is toggled closed
    // (e.g. via the IPC toggle binding), so changes aren't lost when the
    // settings view is dismissed without clicking "save".
    function savePendingSettings() {
        if (root.settingsActive)
            settingsPopup.saveSettings();
    }

    function openChatList() {
        chatList.open();
        settingsPopup.close();
    }

    function prepareToClose() {
        if (root.settingsActive) {
            root.viewToRestore = "settings";
            settingsPopup.close();
            return true;
        }

        if (chatList.isOpen) {
            root.viewToRestore = "chat";
            chatList.close();
            return true;
        }

        // A chat drawer that the user already dismissed must finish sliding
        // out before the main panel starts moving.
        if (chatList.isClosing) {
            root.viewToRestore = "none";
            return true;
        }

        root.viewToRestore = "none";
        return false;
    }

    function restoreAfterPanelOpen() {
        if (root.viewToRestore === "settings")
            root.openSettings();
        else if (root.viewToRestore === "chat")
            root.openChatList();
    }

    function requestViewAfterPanelOpen(view) {
        root.viewToRestore = view;
    }

    function notifyActiveViewClosed() {
        if (!root.settingsActive && !chatList.isOpen && !chatList.isClosing)
            root.activeViewClosed();
    }

    // This is a separate layer-shell surface, so the compositor can blur the
    // main panel and desktop behind it without blurring transparent pixels
    // inside the main panel's own surface.
    BackgroundEffect.blurRegion: Region {
        item: blurRegion
        radius: root.config ? root.config.panelRadius : 26
    }

    Item {
        id: blurRegion
        x: settingsActive ? 0 : chatList.drawerX
        y: 0
        width: settingsActive ? root.width : chatList.drawerWidth
        height: root.height
    }

    Item {
        id: settingsLayer
        anchors.fill: parent

        SettingsPopup {
            id: settingsPopup
            parent: settingsLayer
            x: 0
            y: 0
            width: settingsLayer.width
            height: settingsLayer.height
            settings: root.settings
            config: root.config
            computeCurrentPersonaFn: root.computeCurrentPersonaFn
            generateIdFn: root.generateIdFn

            onPersonaSelected: (id) => {
                root.settings.currentPersonaId = id;
                root.computeCurrentPersonaFn();
            }

            onClosed: {
                root.settingsActive = false;
                root.notifyActiveViewClosed();
            }
        }
    }

    Item {
        id: chatListLayer
        anchors.fill: parent

        SideMenu {
            id: chatList
            parent: chatListLayer
            width: chatListLayer.width
            height: chatListLayer.height
            settings: root.settings
            config: root.config
            sessionManager: root.sessionManager
            currentSessionId: root.currentSessionId
            sessionsModel: root.sessionsModel

            onLoadSessionRequested: (id) => root.loadSessionRequested(id)
            onNewChatRequested: root.newChatRequested()
            onUpdateSessionsModelRequested: root.updateSessionsModelRequested()
            onClosed: root.notifyActiveViewClosed()
        }
    }

    // Keep the chat drawer rendered until its leftward slide has finished so
    // it never appears to fade out.
    visible: settingsActive
        || chatList.isOpen
        || chatList.animating
        || chatList.isClosing
}
