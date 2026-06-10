import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

ColumnLayout {
    id: root

    // Properties (read-only display state from parent)
    property bool isLoading
    property var attachments: []
    property var config

    // Signals - parent handles all logic
    // Signals - parent handles all logic
    signal sendRequested(string text, var attachments)
    signal stopRequested()
    signal modelPickerRequested()
    signal attachmentAdded(string filePath)
    signal attachmentRemoved(int index)

    Layout.fillWidth: true
    spacing: 5

    function forceFocus() {
        inputField.forceActiveFocus();
    }

    // Attachments preview
    RowLayout {
        Layout.fillWidth: true
        visible: root.attachments.length > 0
        spacing: 10

        Repeater {
            model: root.attachments
            RetroFrame {
                id: frameItem
                implicitWidth: 60; implicitHeight: 60
                title: "file"
                borderColor: "#808080"

                Item {
                    width: 36
                    height: 36

                    Image {
                        anchors.fill: parent
                        source: modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i) ? "file://" + modelData : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "FILE"
                        color: "#808080"
                        font.family: "Monospace"
                        font.pixelSize: 8
                        visible: !modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i)
                    }

                    DeleteButton {
                        parent: frameItem
                        anchors.top: frameItem.top
                        anchors.right: frameItem.right
                        anchors.topMargin: 2
                        anchors.rightMargin: 2
                        z: 10
                        onClicked: root.attachmentRemoved(index)
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: Math.min(300, Math.max(80, inputField.implicitHeight + 20))
        color: "#1A1A1A"

        ScrollView {
            anchors.fill: parent
            TextArea {
                id: inputField
                padding: 10
                placeholderText: "type your message..."
                color: "#c5c5c5"
                placeholderTextColor: "#808080"
                font.family: "Monospace"
                font.pixelSize: 14
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
    }

    RowLayout {
        Layout.fillWidth: true
        height: 30

        Rectangle {
            id: paperclipButton
            width: 24
            height: 24
            color: paperclipMouseArea.containsMouse ? "#333333" : "transparent"
            Image {
                source: "paperclip.svg"
                sourceSize: Qt.size(15, 30)
                width: 15
                height: 30
                anchors.centerIn: parent
            }
            MouseArea {
                id: paperclipMouseArea
                hoverEnabled: true
                anchors.fill: parent
                onClicked: fileDialog.open()
            }
        }

        Item { width: 20 }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 5

            Item {
                width: 14
                height: 16
                Image {
                    id: modelPickerArrow
                    source: "dropdown.svg"
                    sourceSize: Qt.size(14, 16)
                    anchors.centerIn: parent
                    rotation: 0
                }
                MouseArea {
                    id: modelPickerArrowMouseArea
                    hoverEnabled: true
                    anchors.fill: parent
                    onClicked: root.modelPickerRequested()
                }
            }

            Item {
                width: modelPickerText.contentWidth
                height: modelPickerText.contentHeight
                Text {
                    id: modelPickerText
                    text: root.config.modelName
                    color: "#c5c5c5"
                    font.family: "Monospace"
                    font.pixelSize: 14
                    anchors.centerIn: parent
                }
                MouseArea {
                    id: modelPickerTextMouseArea
                    hoverEnabled: true
                    anchors.fill: parent
                    onClicked: root.modelPickerRequested()
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Custom Send Button
        Rectangle {
            id: sendButton
            width: 30
            height: 30
            color: "transparent"

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
                text: root.isLoading ? "■" : "→|"
                color: root.isLoading || inputField.text.trim() !== "" || root.attachments.length > 0 ? "#c5c5c5" : "#404040"
                font.family: "Monospace"
                font.pixelSize: root.isLoading ? 24 : 20
            }

            MouseArea {
                anchors.fill: parent
                onClicked: sendButton.send()
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
                if (url.startsWith("file://")) {
                    url = url.substring(7);
                }
                root.attachmentAdded(url);
            }
        }
    }
}
