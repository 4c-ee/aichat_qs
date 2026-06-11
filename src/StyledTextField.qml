import QtQuick
import QtQuick.Controls

TextField {
    id: root

    property var config: null

    color: "#c5c5c5"
    font.family: root.config ? root.config.fontFamily : "Monospace"
    placeholderTextColor: "#808080"

    background: Rectangle {
        color: "#222222"
        border.color: "#404040"
    }
}
