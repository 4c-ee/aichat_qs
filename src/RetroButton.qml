import QtQuick
import QtQuick.Controls

Button {
    id: root

    background: Rectangle {
        color: root.hovered ? "#333333" : "#222222"
        border.color: "#404040"
    }

    contentItem: Text {
        text: root.text
        color: "#c5c5c5"
        font.family: "Monospace"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
