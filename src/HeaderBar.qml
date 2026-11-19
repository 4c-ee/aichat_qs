import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property var currentPersona
    property var settings
    property var config

    signal newChatRequested()
    signal settingsPanelRequested()
    signal chatListPanelRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: 44
    spacing: 10

    // History / thread switcher
    Rectangle {
        id: menuButton
        width: 44
        height: 44
        radius: config.controlRadius
        color: config.surfaceColor
        border.color: config.outerBorderColor
        border.width: 1
        scale: menuTap.pressed ? 0.94 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }

        Image {
            id: menuIcon
            anchors.centerIn: parent
            width: 22
            height: 22
            source: menuHover.hovered ? "menu-hover.svg" : "menu.svg"
            sourceSize: Qt.size(22, 22)
            fillMode: Image.PreserveAspectFit
        }

        HoverHandler {
            id: menuHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: menuTap
            onTapped: root.chatListPanelRequested()
        }
    }

    Item {
        Layout.fillWidth: true
    }

    // Model and panel settings
    Rectangle {
        id: settingsButton
        width: 44
        height: 44
        radius: config.controlRadius
        color: config.surfaceColor
        border.color: config.outerBorderColor
        border.width: 1
        scale: settingsTap.pressed ? 0.94 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }

        Image {
            anchors.centerIn: parent
            width: 23
            height: 23
            source: settingsHover.hovered ? "sliders-hover.svg" : "sliders.svg"
            sourceSize: Qt.size(23, 23)
            fillMode: Image.PreserveAspectFit
        }

        HoverHandler {
            id: settingsHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: settingsTap
            onTapped: root.settingsPanelRequested()
        }
    }
}
