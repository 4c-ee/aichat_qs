import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property var targetItem: null
    property color normalColor: "#808080"
    property color hoverColor: "#FFFFFF"

    signal clicked()

    width: 14
    height: 14
    color: "#1A1A1A"
    border.color: deleteMouseArea.containsMouse ? hoverColor : normalColor
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: "×"
        color: deleteMouseArea.containsMouse ? hoverColor : normalColor
        font.pixelSize: 10
        font.bold: true
        anchors.verticalCenterOffset: -1
    }

    MouseArea {
        id: deleteMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
