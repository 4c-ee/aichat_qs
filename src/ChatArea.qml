import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: root

    property var chatModel
    property var config
    property bool isLoading
    property var formatMessageFn

    signal retryRequested(int historyIndex)
    signal forkRequested(int historyIndex)
    signal messageEdited(int historyIndex, string newText)

    property int editingIndex: -1
    property string editingDraft: ""
    property string thinkingDots: ""

    onEditingIndexChanged: root.forceLayout()

    Timer {
        id: thinkingTimer
        interval: 350
        repeat: true
        running: root.isLoading && chatModel.count > 0
            && chatModel.get(chatModel.count - 1).sender === "ai"
            && chatModel.get(chatModel.count - 1).message === ""
        onTriggered: {
            root.thinkingDots = root.thinkingDots.length >= 3 ? "" : root.thinkingDots + ".";
        }
    }

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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                        text: "you"
                        color: root.config.textMuted
                        font.family: root.config.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    MessageActionButton {
                        Layout.alignment: Qt.AlignVCenter
                        iconSource: "svgs/retry.svg"
                        hoverIconSource: "svgs/retry-hover.svg"
                        tooltipText: "Resend this message"
                        config: root.config
                        enabled: !root.isLoading && root.editingIndex === -1
                        visible: root.editingIndex === -1
                        onClicked: root.retryRequested(model.historyIndex)
                    }

                    MessageActionButton {
                        Layout.alignment: Qt.AlignVCenter
                        iconSource: "svgs/copy.svg"
                        hoverIconSource: "svgs/copy-hover.svg"
                        tooltipText: "Copy message"
                        config: root.config
                        enabled: !root.isLoading && root.editingIndex === -1
                        visible: root.editingIndex === -1
                        onClicked: Qt.application.clipboard().text = model.message
                    }

                    MessageActionButton {
                        Layout.alignment: Qt.AlignVCenter
                        iconSource: "svgs/edit.svg"
                        hoverIconSource: "svgs/edit-hover.svg"
                        tooltipText: "Edit message"
                        config: root.config
                        enabled: !root.isLoading && root.editingIndex === -1
                        visible: root.editingIndex === -1
                        onClicked: {
                            root.editingDraft = model.message;
                            root.editingIndex = index;
                        }
                    }

                    RetroButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.editingIndex === index
                        config: root.config
                        text: "Save"
                        onClicked: {
                            root.messageEdited(model.historyIndex, root.editingDraft);
                            root.editingIndex = -1;
                        }
                    }

                    RetroButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.editingIndex === index
                        config: root.config
                        text: "Cancel"
                        onClicked: root.editingIndex = -1
                    }
                }

                TextEdit {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(22, contentHeight)
                    text: root.editingIndex === index ? root.editingDraft : model.message
                    textFormat: Text.PlainText
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 17
                    wrapMode: Text.WordWrap
                    selectByMouse: true
                    readOnly: root.editingIndex !== index
                    focus: root.editingIndex === index
                    onEditingFinished: {
                        if (root.editingIndex === index) {
                            root.messageEdited(model.historyIndex, root.editingDraft);
                            root.editingIndex = -1;
                        }
                    }
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

            property bool expanded: false

            ColumnLayout {
                id: thoughtColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24

                    Image {
                        id: thoughtArrow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        source: thoughtCard.expanded ? "svgs/chevron-up.svg" : "svgs/chevron-down.svg"
                        sourceSize: Qt.size(14, 14)
                        fillMode: Image.PreserveAspectFit
                        scale: thoughtMouseArea.pressed ? 0.86 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.left: thoughtArrow.right
                        anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Thinking" + root.thinkingDots
                        color: root.config.textMuted
                        font.family: root.config.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: thoughtMouseArea
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

                            Image {
                                id: toolArrow
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                source: toolCard.expanded ? "svgs/chevron-up.svg" : "svgs/chevron-down.svg"
                                sourceSize: Qt.size(14, 14)
                                fillMode: Image.PreserveAspectFit
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                        text: model.modelName || root.config.modelName
                        color: root.config.textMuted
                        font.family: root.config.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    MessageActionButton {
                        Layout.alignment: Qt.AlignVCenter
                        iconSource: "svgs/fork.svg"
                        hoverIconSource: "svgs/fork-hover.svg"
                        tooltipText: "Fork conversation here"
                        config: root.config
                        enabled: !root.isLoading && model.historyIndex >= 0 && root.editingIndex === -1
                        visible: root.editingIndex === -1
                        onClicked: root.forkRequested(model.historyIndex)
                    }

                    MessageActionButton {
                        Layout.alignment: Qt.AlignVCenter
                        iconSource: "svgs/copy.svg"
                        hoverIconSource: "svgs/copy-hover.svg"
                        tooltipText: "Copy message"
                        config: root.config
                        enabled: !root.isLoading && model.historyIndex >= 0 && root.editingIndex === -1
                        visible: root.editingIndex === -1
                        onClicked: Qt.application.clipboard().text = model.message
                    }

                    MessageActionButton {
                        Layout.alignment: Qt.AlignVCenter
                        iconSource: "svgs/edit.svg"
                        hoverIconSource: "svgs/edit-hover.svg"
                        tooltipText: "Edit message"
                        config: root.config
                        enabled: !root.isLoading && model.historyIndex >= 0 && root.editingIndex === -1
                        visible: root.editingIndex === -1
                        onClicked: {
                            root.editingDraft = model.message;
                            root.editingIndex = index;
                        }
                    }

                    RetroButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.editingIndex === index
                        config: root.config
                        text: "Save"
                        onClicked: {
                            root.messageEdited(model.historyIndex, root.editingDraft);
                            root.editingIndex = -1;
                        }
                    }

                    RetroButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.editingIndex === index
                        config: root.config
                        text: "Cancel"
                        onClicked: root.editingIndex = -1
                    }
                }

                TextEdit {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(22, contentHeight)
                    text: root.editingIndex === index ? root.editingDraft : root.formatMessageFn(model.message)
                    textFormat: root.editingIndex === index ? Text.PlainText : Text.RichText
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 17
                    wrapMode: Text.WordWrap
                    selectByMouse: true
                    readOnly: root.editingIndex !== index
                    focus: root.editingIndex === index
                    onEditingFinished: {
                        if (root.editingIndex === index) {
                            root.messageEdited(model.historyIndex, root.editingDraft);
                            root.editingIndex = -1;
                        }
                    }
                }

            }
        }

        // Non-AI system messages (for example API errors)
        Rectangle {
            Layout.fillWidth: true
            visible: model.sender === "system"
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
                    text: "System"
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
