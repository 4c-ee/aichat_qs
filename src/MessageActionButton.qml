import QtQuick
import QtQuick.Controls

Button {
    id: root

    property url iconSource
    property url hoverIconSource: ""
    property string tooltipText: ""
    property var config

    implicitWidth: 30
    implicitHeight: 30
    padding: 0
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    scale: down ? 0.86 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    background: Rectangle {
        radius: root.config.controlRadius
        color: root.hovered && root.enabled ? root.config.nestedSurfaceColor : "transparent"
        border.color: root.hovered && root.enabled ? root.config.accent1 : "transparent"
        border.width: 1
    }

    contentItem: Item {
        implicitWidth: 16
        implicitHeight: 16

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
            source: root.hovered && root.hoverIconSource != ""
                ? root.hoverIconSource
                : root.iconSource
            sourceSize: Qt.size(48, 48)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    ToolTip.visible: root.hovered && root.enabled && root.tooltipText !== ""
    ToolTip.text: root.tooltipText
    ToolTip.delay: 500
}
