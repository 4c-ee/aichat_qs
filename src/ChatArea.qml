import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    // Properties
    property var chatModel
    property var config
    property bool isLoading

    model: chatModel

    // Functions passed from parent
    property var formatMessageFn

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 20
    cacheBuffer: 2000

    delegate: ColumnLayout {
        width: root.width
        height: implicitHeight
        spacing: 0

        RetroFrame {
            id: msgFrame
            Layout.fillWidth: true
            title: sender === "You" ? "user" : "ai"
            borderColor: sender === "You" ? "#c5c5c5" : "#c5c5c5"
            config: root.config

            rightElement: Item {
                implicitWidth: sender === "You" ? 16 : (modelNameText.implicitWidth + 20)
                implicitHeight: sender === "You" ? 16 : 16
                width: implicitWidth
                height: implicitHeight
                Image {
                    visible: sender === "You"
                    source: "pencil.svg"
                    sourceSize: Qt.size(16, 16)
                    anchors.centerIn: parent
                }
                Text {
                    id: modelNameText
                    visible: sender !== "You"
                    text: root.config.modelName
                    color: "#c5c5c5"
                    font.family: root.config.fontFamily
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }
            }
            titlePadding: sender === "You" ? 2 : 10

            ColumnLayout {
                width: parent.width
                height: implicitHeight
                spacing: 15

                // Thought box for AI
                RetroFrame {
                    id: thoughtFrame
                    Layout.fillWidth: true
                    visible: sender === "AI" && (thinking !== "" || root.isLoading && message === "")
                    title: "thought"
                    borderColor: "#808080"
                    property bool collapsed: false
                    stickyScroll: root
                    config: root.config

                    rightElement: Image {
                        source: "dropdown.svg"
                        sourceSize: Qt.size(14, 16)
                        width: 14
                        height: 16
                        rotation: thoughtFrame.collapsed ? -90 : 0
                        MouseArea {
                            anchors.fill: parent
                            onClicked: thoughtFrame.collapsed = !thoughtFrame.collapsed
                        }
                    }

                    TextEdit {
                        width: parent.width
                        visible: !thoughtFrame.collapsed
                        height: visible ? implicitHeight : 0
                        text: root.formatMessageFn(thinking)
                        textFormat: Text.RichText
                        color: "#808080"
                        font.family: root.config.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        selectByMouse: true
                        readOnly: true
                    }
                }

                // Tool box for AI
                RetroFrame {
                    id: toolFrame
                    Layout.fillWidth: true
                    visible: (toolName || "") !== ""
                    title: "tool"
                    borderColor: "#4A90E2"
                    property bool collapsed: false
                    stickyScroll: root
                    config: root.config

                    rightElement: Image {
                        source: "dropdown.svg"
                        sourceSize: Qt.size(14, 16)
                        width: 14
                        height: 16
                        rotation: toolFrame.collapsed ? -90 : 0
                        MouseArea {
                            anchors.fill: parent
                            onClicked: toolFrame.collapsed = !toolFrame.collapsed
                        }
                    }

                    ColumnLayout {
                        width: parent.width
                        visible: !toolFrame.collapsed
                        spacing: 5

                        Text {
                            text: "<b>Call:</b> " + toolName + "[" + toolInput + "]"
                            color: "#c5c5c5"
                            font.family: root.config.fontFamily
                            font.pixelSize: 12
                            textFormat: Text.RichText
                        }

                        Text {
                            text: "<b>Status:</b> " + toolStatus
                            color: "#808080"
                            font.family: root.config.fontFamily
                            font.pixelSize: 10
                            textFormat: Text.RichText
                        }

                        TextEdit {
                            Layout.fillWidth: true
                            text: toolOutput
                            color: "#808080"
                            font.family: root.config.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            selectByMouse: true
                            readOnly: true
                            visible: toolOutput !== ""
                        }
                    }
                }

                TextEdit {
                    Layout.fillWidth: true
                    text: sender === "AI" ? root.formatMessageFn(message) : message
                    textFormat: sender === "AI" ? Text.RichText : Text.PlainText
                    color: "#c5c5c5"
                    font.family: root.config.fontFamily
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    visible: message !== ""
                    selectByMouse: true
                    readOnly: true
                }
            }
        }
    }
}
