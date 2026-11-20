import QtQuick

QtObject {
    id: root

    // API configuration
    property string modelName: ""
    property real temperature: 0.7
    property bool enableStreaming: true

    // Typography
    property string fontFamily: "Google Sans Flex"

    // Geometry
    property int panelWidth: 500
    property int panelRadius: 26
    property int cardRadius: 18
    property int controlRadius: 12
    property int outerMargin: 16

    // The glass hierarchy intentionally reuses the same alpha at every level.
    // Nested surfaces therefore become darker by additive composition alone.
    readonly property color surfaceColor: Qt.rgba(0, 0, 0, 0.20)
    readonly property color nestedSurfaceColor: Qt.rgba(0, 0, 0, 0.20)
    readonly property color outerBorderColor: Qt.rgba(0, 0, 0, 0.40)
    readonly property color subtleBorderColor: Qt.rgba(0, 0, 0, 0.24)

    // Core palette
    readonly property color textMain: "#e0fafc"
    readonly property color textMuted: "#b6cacc"
    readonly property color accent1: "#c2ffb3"
    readonly property color accent1Hover: "#e9ffe3"
    readonly property color accent2: "#c0f8fc"
    readonly property color dangerColor: "#ffb3b3"
}
