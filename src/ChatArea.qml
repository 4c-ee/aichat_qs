import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    property var chatModel
    property var config
    property bool isLoading
    property var formatMessageFn

    model: chatModel

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 12
    topMargin: 2
    bottomMargin: 4
    cacheBuffer: 2400

    delegate: ColumnLayout {
        id: messageDelegate
        width: root.width
        spacing: 12

        // User prompt
        Rectangle {
            Layout.fillWidth: true
            visible: model.sender === "you"
            implicitHeight: userColumn.implicitHeight + 30
            radius: root.config.cardRadius
            color: root.config.surfaceColor
            border.color: root.config.outerBorderColor
            border.width: 1

            ColumnLayout {
                id: userColumn
                anchors.fill: parent
                anchors.margins: 15
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: "you"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: model.message
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 17
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        // Collapsible reasoning and tool-use card
        Rectangle {
            id: thoughtCard
            Layout.fillWidth: true
            visible: model.sender === "ai" && (model.thinking !== "" || model.toolName !== "" || (root.isLoading && model.message === ""))
            implicitHeight: thoughtColumn.implicitHeight + 28
            radius: root.config.cardRadius
            color: root.config.surfaceColor
            border.color: root.config.outerBorderColor
            border.width: 1

            property bool expanded: true

            ColumnLayout {
                id: thoughtColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24

                    Text {
                        id: thoughtArrow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: thoughtCard.expanded ? "▼" : "▶"
                        color: root.config.accent1
                        font.family: root.config.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.left: thoughtArrow.right
                        anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thinking..."
                        color: root.config.accent1
                        font.family: root.config.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: thoughtCard.expanded = !thoughtCard.expanded
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: thoughtCard.expanded && model.thinking !== ""
                    text: model.thinking
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    visible: thoughtCard.expanded && model.thinking === "" && root.isLoading
                    text: "Preparing a response..."
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 15
                    font.italic: true
                }

                // Nested tool-call pill
                Rectangle {
                    id: toolCard
                    Layout.fillWidth: true
                    visible: model.toolName !== ""
                    implicitHeight: toolColumn.implicitHeight + 18
                    radius: 14
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.subtleBorderColor
                    border.width: 1

                    property bool expanded: false

                    ColumnLayout {
                        id: toolColumn
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22

                            Text {
                                id: toolArrow
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: toolCard.expanded ? "▼" : "▶"
                                color: root.config.accent1
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.left: toolArrow.right
                                anchors.leftMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tool call: "
                                color: root.config.textMain
                                font.family: root.config.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 27
                                anchors.bottom: parent.bottom
                                text: model.toolName === "search" ? "Web Search" : (model.toolName === "getpage" ? "Get Page" : model.toolName)
                                color: root.config.textMain
                                font.family: root.config.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toolCard.expanded = !toolCard.expanded
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: toolCard.expanded
                            spacing: 7

                            Text {
                                Layout.fillWidth: true
                                visible: model.toolInput !== ""
                                text: "Input: " + model.toolInput
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: model.toolStatus !== ""
                                text: "Status: " + model.toolStatus
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                            }

                            TextEdit {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(18, contentHeight)
                                visible: model.toolOutput !== ""
                                text: model.toolOutput
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                selectByMouse: true
                                readOnly: true
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }
            }
        }

        // Assistant response
        Rectangle {
            Layout.fillWidth: true
            visible: model.sender === "ai" && model.message !== ""
            implicitHeight: responseColumn.implicitHeight + 30
            radius: root.config.cardRadius
            color: root.config.surfaceColor
            border.color: root.config.outerBorderColor
            border.width: 1

            ColumnLayout {
                id: responseColumn
                anchors.fill: parent
                anchors.margins: 15
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.config.modelName
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                TextEdit {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(22, contentHeight)
                    text: root.formatMessageFn(model.message)
                    textFormat: Text.RichText
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 17
                    wrapMode: Text.WordWrap
                    selectByMouse: true
                    readOnly: true
                }
            }
        }

        // Non-AI system messages (for example API errors)
        Rectangle {
            Layout.fillWidth: true
            visible: model.sender !== "you" && model.sender !== "ai"
            implicitHeight: systemColumn.implicitHeight + 30
            radius: root.config.cardRadius
            color: root.config.surfaceColor
            border.color: root.config.outerBorderColor
            border.width: 1

            ColumnLayout {
                id: systemColumn
                anchors.fill: parent
                anchors.margins: 15
                spacing: 5

                Text {
                    text: model.sender === "System" ? "System" : model.sender
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: model.message
                    color: root.config.dangerColor
                    font.family: root.config.fontFamily
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
