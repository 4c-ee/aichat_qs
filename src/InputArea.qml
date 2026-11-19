import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

ColumnLayout {
    id: root

    property bool isLoading
    property var attachments: []
    property var config

    signal sendRequested(string text, var attachments)
    signal stopRequested()
    signal modelPickerRequested()
    signal attachmentAdded(string filePath)
    signal attachmentRemoved(int index)

    Layout.fillWidth: true
    spacing: 8

    function forceFocus() {
        inputField.forceActiveFocus();
    }

    // Attachment preview
    Flow {
        Layout.fillWidth: true
        visible: root.attachments.length > 0
        spacing: 8

        Repeater {
            model: root.attachments

            Rectangle {
                id: attachmentTile
                width: 54
                height: 54
                radius: 13
                color: root.config.nestedSurfaceColor
                border.color: root.config.subtleBorderColor
                border.width: 1

                Image {
                    anchors.fill: parent
                    anchors.margins: 8
                    source: modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i) ? "file://" + modelData : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i)
                }

                Text {
                    anchors.centerIn: parent
                    text: "FILE"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    visible: !modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i)
                }

                DeleteButton {
                    parent: attachmentTile
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 3
                    z: 10
                    normalColor: root.config.textMuted
                    hoverColor: root.config.accent1Hover
                    onClicked: root.attachmentRemoved(index)
                }
            }
        }
    }

    // Pinned composer
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: composerColumn.implicitHeight + 24
        radius: 20
        color: root.config.surfaceColor
        border.color: root.config.outerBorderColor
        border.width: 1

        ColumnLayout {
            id: composerColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            ScrollView {
                id: inputScroll
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(150, Math.max(54, inputField.contentHeight + 12))
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    id: inputField
                    width: Math.max(0, inputScroll.availableWidth)
                    padding: 4
                    placeholderText: "write a message..."
                    color: root.config.textMain
                    placeholderTextColor: root.config.textMuted
                    selectionColor: root.config.accent2
                    selectedTextColor: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 16
                    enabled: !root.isLoading
                    wrapMode: Text.WordWrap
                    background: null

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return && event.modifiers === Qt.ControlModifier) {
                            sendButton.send();
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.config.subtleBorderColor
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 8

                // Model quick-switch
                Rectangle {
                    id: modelButton
                    Layout.preferredWidth: Math.min(220, modelText.implicitWidth + 48)
                    Layout.preferredHeight: 34
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1
                    scale: modelMouseArea.pressed ? 0.96 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "▶"
                            color: root.config.accent1
                            font.family: root.config.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }

                        Text {
                            id: modelText
                            Layout.fillWidth: true
                            text: root.config.modelName
                            color: root.config.textMain
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: modelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.modelPickerRequested()
                    }
                }

                // Attachment action
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 34
                    radius: 9
                    color: "transparent"

                    Image {
                        anchors.centerIn: parent
                        width: 15
                        height: 20
                        source: attachmentMouseArea.containsMouse ? "paperclip-hover.svg" : "paperclip.svg"
                        sourceSize: Qt.size(15, 20)
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: attachmentMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fileDialog.open()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Primary send / stop action
                Rectangle {
                    id: sendButton
                    Layout.preferredWidth: 86
                    Layout.preferredHeight: 36
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1
                    scale: sendMouseArea.pressed ? 0.94 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    function send() {
                        if (!root.isLoading && (inputField.text.trim() !== "" || root.attachments.length > 0)) {
                            var text = inputField.text.trim();
                            root.sendRequested(text, [...root.attachments]);
                            inputField.text = "";
                        } else if (root.isLoading) {
                            root.stopRequested();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.isLoading ? "stop ■" : "send →"
                        color: sendMouseArea.containsMouse ? root.config.accent1Hover : root.config.accent1
                        font.family: root.config.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: sendMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sendButton.send()
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Select attachments"
        currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            for (var i = 0; i < selectedFiles.length; i++) {
                var url = selectedFiles[i].toString();
                if (url.startsWith("file://"))
                    url = url.substring(7);
                root.attachmentAdded(url);
            }
        }
    }
}
