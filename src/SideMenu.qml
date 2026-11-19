import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string currentSessionId
    property var settings
    property var sessionsModel
    property var config

    signal loadSessionRequested(string id)
    signal newChatRequested()
    signal updateSessionsModelRequested()
    signal closed()

    width: parent.width
    height: parent.height
    z: 100

    property bool isOpen: false
    property bool isClosing: false
    property bool animating: false
    readonly property real drawerWidth: Math.min(340, root.width)
    readonly property real drawerX: drawer.x

    function open() {
        root.isClosing = false;
        root.isOpen = true;
    }

    function close() {
        if (!root.isOpen && !root.isClosing)
            return;

        root.isClosing = true;
        root.animating = true;
        root.isOpen = false;
    }

    MouseArea {
        anchors.fill: parent
        visible: root.isOpen
        acceptedButtons: Qt.LeftButton
        onClicked: root.close()
    }

    Rectangle {
        id: drawer
        width: root.drawerWidth
        height: root.height
        color: root.config.surfaceColor
        border.color: root.config.outerBorderColor
        border.width: 1
        radius: root.config.panelRadius

        x: root.isOpen ? 0 : -width - 2
        Behavior on x {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    root.animating = running;
                    if (!running && !root.isOpen) {
                        root.isClosing = false;
                        root.closed();
                    }
                }
            }
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            enabled: root.isOpen
            onActivated: root.close()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1
                    scale: closeMouseArea.pressed ? 0.94 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: closeMouseArea.containsMouse ? root.config.accent1Hover : root.config.textMain
                        font.family: root.config.fontFamily
                        font.pixelSize: 23
                    }

                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "chat history"
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                }

                RetroButton {
                    text: "+ new"
                    config: root.config
                    onClicked: {
                        root.newChatRequested();
                        root.close();
                    }
                }
            }

            ListView {
                id: sessionsListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.sessionsModel
                spacing: 8

                remove: Transition {
                    NumberAnimation {
                        properties: "opacity"
                        from: 1
                        to: 0
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                removeDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: ItemDelegate {
                    id: sessionDelegate
                    width: sessionsListView.width
                    height: 58
                    padding: 12

                    contentItem: RowLayout {
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: root.currentSessionId === model.id ? root.config.accent1 : root.config.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: model.title
                            color: root.currentSessionId === model.id ? root.config.textMain : root.config.textMuted
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            font.weight: root.currentSessionId === model.id ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: deleteMouseArea.containsMouse ? Qt.rgba(1, 0.35, 0.35, 0.24) : Qt.rgba(1, 0.35, 0.35, 0.12)
                            border.color: root.config.dangerColor
                            border.width: 1
                            scale: deleteMouseArea.pressed ? 0.88 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.config.dangerColor
                                font.family: root.config.fontFamily
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var sessions = JSON.parse(root.settings.savedSessions);
                                    var index = sessions.findIndex(s => s.id === model.id);
                                    if (index !== -1) {
                                        sessions.splice(index, 1);
                                        root.settings.savedSessions = JSON.stringify(sessions);
                                        root.updateSessionsModelRequested();
                                        if (root.currentSessionId === model.id) {
                                            if (sessions.length > 0)
                                                root.loadSessionRequested(sessions[0].id);
                                            else
                                                root.newChatRequested();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    background: Rectangle {
                        radius: root.config.controlRadius
                        color: root.config.surfaceColor
                        border.color: root.currentSessionId === model.id ? root.config.accent1 : root.config.subtleBorderColor
                        border.width: 1
                    }

                    onClicked: {
                        root.loadSessionRequested(model.id);
                        root.close();
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: sessionsListView.count === 0
                text: "No conversations yet"
                color: root.config.textMuted
                font.family: root.config.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
