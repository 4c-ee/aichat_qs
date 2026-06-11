import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ApiClient.js" as ApiClientJs

Item {
    id: root

    // Properties passed from parent
    property string currentSessionId
    property var settings
    property var sessionsModel
    property var config

    // Signals to communicate with parent
    signal loadSessionRequested(string id)
    signal newChatRequested()
    signal updateSessionsModelRequested()

    width: 300
    height: parent.height
    z: 100

    property bool isOpen: false

    function open() { isOpen = true; }
    function close() { isOpen = false; }

    // Background overlay for the rest of the panel to close on click
    MouseArea {
        x: 0
        y: 0
        width: root.width
        height: root.height
        visible: root.isOpen
        onClicked: root.close()
    }

    Rectangle {
        width: 300
        height: parent.height
        color: "#1A1A1A"
        border.color: "#404040"
        border.width: 1

        x: root.isOpen ? 0 : -width
        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // Catch clicks on the menu itself
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            Text {
                text: "Chat History"
                color: "#c5c5c5"
                font.family: root.config.fontFamily
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }

            ListView {
                id: sessionsListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: sessionsModel
                spacing: 5
                delegate: ItemDelegate {
                    id: sessionDelegate
                    width: sessionsListView.width
                    height: 50
                    padding: 10
                    contentItem: RowLayout {
                        Text {
                            text: title
                            color: root.currentSessionId === id ? "#FFFFFF" : "#c5c5c5"
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Item {
                            width: 20
                            height: 20
                            Text {
                                text: "×"
                                color: "#808080"
                                font.pixelSize: 20
                                visible: sessionDelegate.hovered
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var sessions = JSON.parse(root.settings.savedSessions);
                                    var index = sessions.findIndex(s => s.id === id);
                                    if (index !== -1) {
                                        sessions.splice(index, 1);
                                        root.settings.savedSessions = JSON.stringify(sessions);
                                        root.updateSessionsModelRequested();
                                        if (root.currentSessionId === id) {
                                            if (sessions.length > 0) root.loadSessionRequested(sessions[0].id);
                                            else root.newChatRequested();
                                        }
                                    }
                                }
                            }
                        }
                    }
                    background: Rectangle {
                        color: hovered ? "#333333" : (root.currentSessionId === id ? "#222222" : "transparent")
                        border.color: root.currentSessionId === id ? "#404040" : "transparent"
                    }
                    onClicked: {
                        root.loadSessionRequested(id);
                        root.close();
                    }
                }
            }

            Button {
                text: "New Chat"
                Layout.fillWidth: true
                onClicked: {
                    root.newChatRequested();
                    root.close();
                }
                background: Rectangle {
                    color: parent.hovered ? "#333333" : "#1A1A1A"
                    border.color: "#404040"
                }
                contentItem: Text {
                    text: parent.text
                    color: "#c5c5c5"
                    font.family: root.config.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
