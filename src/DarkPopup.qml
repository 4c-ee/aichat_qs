import QtQuick
import QtQuick.Controls

Popup {
    id: root

    modal: true
    focus: true
    padding: 18

    background: Rectangle {
        radius: 18
        color: "#33000000"
        border.color: "#66000000"
        border.width: 1
    }
}
