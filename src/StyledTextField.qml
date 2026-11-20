import QtQuick
import QtQuick.Controls

TextField {
    id: root

    property var config

    color: root.config.textMain
    placeholderTextColor: root.config.textMuted
    selectionColor: root.config.accent2
    selectedTextColor: root.config.textMain
    font.family: root.config.fontFamily
    font.pixelSize: 14
    leftPadding: 12
    rightPadding: 12
    topPadding: 9
    bottomPadding: 9

    background: Rectangle {
        radius: root.config.controlRadius
        color: root.config.nestedSurfaceColor
        border.color: root.activeFocus ? root.config.accent1 : root.config.outerBorderColor
        border.width: 1
    }
}
