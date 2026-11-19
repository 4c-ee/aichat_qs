import QtQuick
import QtQuick.Controls

Button {
    id: root

    property var config: null

    padding: 12
    hoverEnabled: true

    background: Rectangle {
        radius: root.config ? root.config.controlRadius : 10
        color: root.config ? root.config.nestedSurfaceColor : "#33000000"
        border.color: root.hovered
            ? (root.config ? root.config.accent1 : "#c2ffb3")
            : (root.config ? root.config.outerBorderColor : "#66000000")
        border.width: 1
    }

    contentItem: Text {
        text: root.text
        color: root.hovered
            ? (root.config ? root.config.accent1Hover : "#e9ffe3")
            : (root.config ? root.config.accent1 : "#c2ffb3")
        font.family: root.config ? root.config.fontFamily : "Google Sans Flex"
        font.pixelSize: 14
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
