import QtQuick
import QtQuick.Controls

Button {
    id: root

    property var config

    padding: 12
    hoverEnabled: true

    background: Rectangle {
        radius: root.config.controlRadius
        color: root.config.nestedSurfaceColor
        border.color: root.hovered ? root.config.accent1 : root.config.outerBorderColor
        border.width: 1
    }

    contentItem: Text {
        text: root.text
        color: root.hovered ? root.config.accent1Hover : root.config.accent1
        font.family: root.config.fontFamily
        font.pixelSize: 14
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
