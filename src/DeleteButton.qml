import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property var targetItem: null
    property color normalColor: "#b6cacc"
    property color hoverColor: "#e9ffe3"

    signal clicked()

    width: 17
    height: 17
    radius: 9
    color: "#33000000"
    border.color: deleteMouseArea.containsMouse ? hoverColor : normalColor
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: "×"
        color: deleteMouseArea.containsMouse ? hoverColor : normalColor
        font.family: "Google Sans Flex"
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    MouseArea {
        id: deleteMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
