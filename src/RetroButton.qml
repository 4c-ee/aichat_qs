import QtQuick
import QtQuick.Controls

Button {
    id: root

    property var config: null

    background: Rectangle {
        color: root.hovered ? "#333333" : "#222222"
        border.color: "#404040"
    }

    contentItem: Text {
        text: root.text
        color: "#c5c5c5"
        font.family: root.config ? root.config.fontFamily : "Monospace"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
