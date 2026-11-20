import QtQuick
import QtQuick.Controls

Popup {
    id: root

    property var config

    modal: true
    focus: true
    padding: root.config.outerMargin

    background: Rectangle {
        radius: root.config.cardRadius
        color: root.config.surfaceColor
        border.color: root.config.outerBorderColor
        border.width: 1
    }
}
