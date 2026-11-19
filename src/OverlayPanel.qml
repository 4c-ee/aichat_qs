import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var config
    property var settings
    property var sessionsModel
    property var generateIdFn
    property string currentSessionId
    property bool settingsActive: false

    signal loadSessionRequested(string id)
    signal newChatRequested()
    signal updateSessionsModelRequested()

    anchors {
        left: true
        top: true
        bottom: true
    }

    implicitWidth: config ? config.panelWidth : 500
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aichat_qs"
    WlrLayershell.keyboardFocus: (settingsActive || chatList.isOpen)
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand
    exclusiveZone: 0

    function openSettings() {
        chatList.close();
        root.settingsActive = true;
        settingsPopup.open();
    }

    function openChatList() {
        settingsPopup.close();
        chatList.open();
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

    SettingsPopup {
        id: settingsPopup
        x: 0
        y: 0
        width: root.width
        height: root.height
        settings: root.settings
        config: root.config
        generateIdFn: root.generateIdFn

        onPersonaSelected: (id) => {
            root.settings.currentPersonaId = id;
        }

        onClosed: root.settingsActive = false
    }

    SideMenu {
        id: chatList
        settings: root.settings
        config: root.config
        currentSessionId: root.currentSessionId
        sessionsModel: root.sessionsModel

        onLoadSessionRequested: (id) => root.loadSessionRequested(id)
        onNewChatRequested: root.newChatRequested()
        onUpdateSessionsModelRequested: root.updateSessionsModelRequested()
    }

    // Keep the surface alive while the drawer animates closed so its blur
    // region follows it out of view.
    visible: settingsActive
        || chatList.isOpen
        || (chatList.drawerX > -chatList.drawerWidth && chatList.drawerX < 0)
}
