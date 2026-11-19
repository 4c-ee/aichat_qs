import QtQuick
import QtQuick.Controls

TextField {
    id: root

    property var config: null

    color: root.config ? root.config.textMain : "#e0fafc"
    placeholderTextColor: root.config ? root.config.textMuted : "#b6cacc"
    selectionColor: root.config ? root.config.accent2 : "#c0f8fc"
    selectedTextColor: root.config ? root.config.textMain : "#e0fafc"
    font.family: root.config ? root.config.fontFamily : "Google Sans Flex"
    font.pixelSize: 14
    leftPadding: 12
    rightPadding: 12
    topPadding: 9
    bottomPadding: 9

    background: Rectangle {
        radius: root.config ? root.config.controlRadius : 10
        color: root.config ? root.config.nestedSurfaceColor : "#33000000"
        border.color: root.activeFocus
            ? (root.config ? root.config.accent1 : "#c2ffb3")
            : (root.config ? root.config.outerBorderColor : "#66000000")
        border.width: 1
    }
}
