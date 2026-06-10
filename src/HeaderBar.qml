import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property var currentPersona
    property bool sideMenuOpen
    property var settings
    property var sideMenu

    signal newChatRequested()
    signal settingsRequested()

    height: 40

    Rectangle {
        width: 40
        height: 28
        color: menuMouseArea.containsMouse ? "#333333" : "transparent"
        Image {
            source: "menu.svg"
            sourceSize: Qt.size(37, 24)
            anchors.centerIn: parent
        }
        MouseArea {
            id: menuMouseArea
            hoverEnabled: true
            anchors.fill: parent
            onClicked: {
                if (root.sideMenu.isOpen) {
                    root.sideMenu.close();
                } else {
                    root.sideMenu.open();
                }
            }
        }
    }

    Rectangle {
        width: 28
        height: 28
        color: plusMouseArea.containsMouse ? "#333333" : "transparent"
        Image {
            source: "plus.svg"
            sourceSize: Qt.size(20, 20)
            anchors.centerIn: parent
        }
        MouseArea {
            id: plusMouseArea
            hoverEnabled: true
            anchors.fill: parent
            onClicked: root.newChatRequested()
        }
    }

    Item { Layout.fillWidth: true }

    Text {
        text: root.currentPersona.name
        color: "#808080"
        font.family: "Monospace"
        font.pixelSize: 12
        Layout.alignment: Qt.AlignVCenter
    }

    Rectangle {
        width: 28
        height: 28
        color: settingsMouseArea.containsMouse ? "#333333" : "transparent"
        Image {
            source: "cog.svg"
            sourceSize: Qt.size(24, 24)
            anchors.centerIn: parent
            fillMode: Image.Pad
        }
        MouseArea {
            id: settingsMouseArea
            hoverEnabled: true
            anchors.fill: parent
            onClicked: root.settingsRequested()
        }
    }
}