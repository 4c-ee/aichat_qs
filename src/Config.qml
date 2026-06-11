import QtQuick

QtObject {
    // API Configuration
    // These could be loaded from a file or environment variables in a future stage
    property string apiEndpoint: "http://localhost:11435/v1"
    property string apiKey: "wawa" // User needs to provide this
    property string modelName: "gemini-3.5-flash"
    property real temperature: 0.7
    property bool enableStreaming: true
    property string searxngUrl: "http://localhost:8080"
    property bool summarizeSearch: true
    // UI Configuration
    property color backgroundColor: "#000000"
    property color accentColor: "#c5c5c5"
    property int panelWidth: 500 // Increased width for better terminal feel
    property string fontFamily: "Monospace"
}
