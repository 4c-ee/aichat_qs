import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    // Properties
    property var settings
    property var config
    property var generateIdFn

    // Signals
    signal personaSelected(string id)
    signal personaEdited()
    signal personaDeleted()
    signal settingsUpdated()

    x: 0
    y: 0
    width: parent.width
    height: parent.height
    modal: true
    focus: true
    padding: 20

    onOpened: {
        personasModel.clear();
        var ps = JSON.parse(root.settings.personas);
        ps.forEach(p => personasModel.append(p));
    }

    background: Rectangle {
        color: "#1A1A1A"
        border.color: "#404040"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        Text {
            text: "Settings"
            color: "#c5c5c5"
            font.family: "Monospace"
            font.pixelSize: 20
            Layout.alignment: Qt.AlignHCenter
        }

        ScrollView {
            id: settingsScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: settingsScrollView.availableWidth
                spacing: 25

                // Configuration Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text { text: "CONFIGURATION"; color: "#808080"; font.family: "Monospace"; font.pixelSize: 12 }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Text { text: "API Endpoint"; color: "#c5c5c5"; font.family: "Monospace"; font.pixelSize: 12 }
                        StyledTextField {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 250
                            text: root.settings.apiEndpoint
                            placeholderText: "http://..."
                            onTextChanged: {
                                root.settings.apiEndpoint = text;
                                root.config.apiEndpoint = text;
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Text { text: "API Key"; color: "#c5c5c5"; font.family: "Monospace"; font.pixelSize: 12 }
                        RowLayout {
                            Layout.fillWidth: true
                            StyledTextField {
                                id: apiKeyField
                                Layout.fillWidth: true
                                Layout.minimumWidth: 200
                                text: root.settings.apiKey
                                echoMode: showApiKey.checked ? TextInput.Normal : TextInput.Password
                                onTextChanged: {
                                    root.settings.apiKey = text;
                                    root.config.apiKey = text;
                                }
                            }
                            CheckBox {
                                id: showApiKey
                                text: "Show"
                                background: Rectangle { color: "#222222"; border.color: "#404040" }
                                contentItem: Text { text: "Show"; color: "#c5c5c5"; font.family: "Monospace"; leftPadding: 25 }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Text { text: "SearXNG URL"; color: "#c5c5c5"; font.family: "Monospace"; font.pixelSize: 12 }
                        StyledTextField {
                            Layout.fillWidth: true
                            text: root.settings.searxngUrl
                            placeholderText: "http://localhost:8080"
                            onTextChanged: {
                                root.settings.searxngUrl = text;
                                root.config.searxngUrl = text;
                            }
                        }
                    }

                    CheckBox {
                        text: "Summarize Search Results"
                        checked: root.settings.summarizeSearch
                        background: Rectangle { color: "#222222"; border.color: "#404040" }
                        contentItem: Text { text: "Summarize Search Results"; color: "#c5c5c5"; font.family: "Monospace"; leftPadding: 25 }
                        onCheckedChanged: {
                            root.settings.summarizeSearch = checked;
                            root.config.summarizeSearch = checked;
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Text {
                            text: "Temperature: " + root.settings.temperature.toFixed(1)
                            color: "#c5c5c5"
                            font.family: "Monospace"
                            font.pixelSize: 12
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            height: 20
                            Item { width: 5 }
                            Rectangle {
                                id: temperatureSliderTrackContainer
                                Layout.fillWidth: true
                                height: 6
                                color: "#222222"
                                radius: 3
                                Rectangle {
                                    id: temperatureTrack
                                    width: (root.settings.temperature / 2.0) * parent.width
                                    height: parent.height
                                    color: "#c5c5c5"
                                    radius: 3
                                }
                                Rectangle {
                                    id: temperatureHandle
                                    width: 12
                                    height: 12
                                    x: Math.max(0, Math.min(parent.width - width, temperatureTrack.width - width / 2))
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#c5c5c5"
                                    border.color: "#404040"
                                    border.width: 1
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var ratio = mouse.x / width;
                                        var newVal = ratio * 2.0;
                                        newVal = Math.round(newVal * 10) / 10;
                                        root.settings.temperature = Math.max(0, Math.min(2.0, newVal));
                                        root.config.temperature = root.settings.temperature;
                                    }
                                    onPositionChanged: {
                                        if (mouse.buttons === Qt.LeftButton) {
                                            var ratio = mouse.x / width;
                                            var newVal = ratio * 2.0;
                                            newVal = Math.round(newVal * 10) / 10;
                                            root.settings.temperature = Math.max(0, Math.min(2.0, newVal));
                                            root.config.temperature = root.settings.temperature;
                                        }
                                    }
                                }
                            }
                            Item { width: 5 }
                        }
                    }
                }

                // Personas Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text { text: "PERSONAS"; color: "#808080"; font.family: "Monospace"; font.pixelSize: 12 }

                    ListView {
                        id: personasListView
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        interactive: false
                        model: ListModel { id: personasModel }
                        spacing: 10
                        delegate: Rectangle {
                            width: personasListView.width
                            height: implicitHeight
                            implicitHeight: personaCol.implicitHeight + 20
                            color: root.settings.currentPersonaId === id ? "#222222" : "transparent"
                            border.color: "#404040"

                            ColumnLayout {
                                id: personaCol
                                anchors.fill: parent
                                anchors.margins: 10

                                Text {
                                    text: name
                                    color: "#FFFFFF"
                                    font.family: "Monospace"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "System: " + system.substring(0, 50) + (system.length > 50 ? "..." : "")
                                    color: "#808080"
                                    font.family: "Monospace"
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }
                                    RetroButton {
                                        text: "Select"
                                        visible: root.settings.currentPersonaId !== id
                                        onClicked: root.personaSelected(id)
                                    }
                                    RetroButton {
                                        text: "Edit"
                                        onClicked: {
                                            editPersonaPopup.editingId = id;
                                            editPersonaName.text = name;
                                            editPersonaSystem.text = system;
                                            editPersonaPersonality.text = personality || "";
                                            editPersonaPopup.open();
                                        }
                                    }
                                    RetroButton {
                                        text: "Delete"
                                        visible: id !== "default"
                                        onClicked: {
                                            var ps = JSON.parse(root.settings.personas);
                                            var idx = ps.findIndex(p => p.id === id);
                                            if (idx !== -1) {
                                                ps.splice(idx, 1);
                                                root.settings.personas = JSON.stringify(ps);
                                                if (root.settings.currentPersonaId === id) root.settings.currentPersonaId = "default";

                                                personasModel.clear();
                                                ps.forEach(p => personasModel.append(p));
                                                root.personaDeleted();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RetroButton {
                        text: "+ Add Persona"
                        Layout.fillWidth: true
                        onClicked: {
                            newPersonaSystem.text = "You are a helpful assistant. System Info:\\n- OS: {os}\\n- Kernel: {kernel}\\n- DE: {de}\\n- User: {user}\\n- Host: {hostname}\\n- Time: {date time}\\n\\n# Tool Use\\nYou can call tools by outputting tool[\\\"(tool_name)\\\", \\\"input1\\\", \\\"input2\\\"].\\nThe tool call MUST be at the end of your response.\\n\\nAvailable tools:\\n- tool[\\\"search\\\", \\\"query\\\"]: Searches the web using SearXNG. Returns top results and text from the first 3.\\n- tool[\\\"getpage\\\", \\\"url\\\", \\\"prompt\\\"]: Fetches a URL and uses a separate model to extract info based on the prompt.";
                            addPersonaPopup.open();
                        }
                    }
                }
            }
        }

        RetroButton {
            text: "Close"
            Layout.alignment: Qt.AlignRight
            onClicked: root.close()
        }
    }

    // Add Persona Popup
    DarkPopup {
        id: addPersonaPopup
        anchors.centerIn: parent
        width: 400
        height: 500

        ScrollView {
            id: addPersonaScrollView
            anchors.fill: parent
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: addPersonaScrollView.availableWidth
                spacing: 15

                Text {
                    text: "Add New Persona"
                    color: "#c5c5c5"
                    font.family: "Monospace"
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }

                StyledTextField {
                    id: newPersonaName
                    Layout.fillWidth: true
                    placeholderText: "Name"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "#222222"
                    border.color: "#404040"
                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: newPersonaSystem
                            padding: 10
                            placeholderText: "System Prompt"
                            color: "#c5c5c5"
                            placeholderTextColor: "#808080"
                            font.family: "Monospace"
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    color: "#222222"
                    border.color: "#404040"
                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: newPersonaPersonality
                            padding: 10
                            placeholderText: "Personality Prompt (Optional)"
                            color: "#c5c5c5"
                            placeholderTextColor: "#808080"
                            font.family: "Monospace"
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    RetroButton {
                        text: "Cancel"
                        onClicked: addPersonaPopup.close()
                    }
                    RetroButton {
                        text: "Save"
                        onClicked: {
                            if (newPersonaName.text !== "") {
                                var ps = JSON.parse(root.settings.personas);
                                var newP = {
                                    id: root.generateIdFn(),
                                    name: newPersonaName.text,
                                    system: newPersonaSystem.text,
                                    personality: newPersonaPersonality.text
                                };
                                ps.push(newP);
                                root.settings.personas = JSON.stringify(ps);

                                // Refresh model
                                personasModel.clear();
                                ps.forEach(p => personasModel.append(p));

                                newPersonaName.text = "";
                                newPersonaSystem.text = "";
                                newPersonaPersonality.text = "";
                                addPersonaPopup.close();
                            }
                        }
                    }
                }
            }
        }
    }

    // Edit Persona Popup
    DarkPopup {
        id: editPersonaPopup
        anchors.centerIn: parent
        width: 400
        height: 500

        property string editingId: ""

        ScrollView {
            id: editPersonaScrollView
            anchors.fill: parent
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: editPersonaScrollView.availableWidth
                spacing: 15

                Text {
                    text: "Edit Persona"
                    color: "#c5c5c5"
                    font.family: "Monospace"
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }

                StyledTextField {
                    id: editPersonaName
                    Layout.fillWidth: true
                    placeholderText: "Name"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "#222222"
                    border.color: "#404040"
                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: editPersonaSystem
                            padding: 10
                            placeholderText: "System Prompt"
                            color: "#c5c5c5"
                            placeholderTextColor: "#808080"
                            font.family: "Monospace"
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    color: "#222222"
                    border.color: "#404040"
                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: editPersonaPersonality
                            padding: 10
                            placeholderText: "Personality Prompt (Optional)"
                            color: "#c5c5c5"
                            placeholderTextColor: "#808080"
                            font.family: "Monospace"
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    RetroButton {
                        text: "Cancel"
                        onClicked: editPersonaPopup.close()
                    }
                    RetroButton {
                        text: "Save"
                        onClicked: {
                            if (editPersonaName.text !== "") {
                                var ps = JSON.parse(root.settings.personas);
                                var idx = ps.findIndex(p => p.id === editPersonaPopup.editingId);
                                if (idx !== -1) {
                                    ps[idx].name = editPersonaName.text;
                                    ps[idx].system = editPersonaSystem.text;
                                    ps[idx].personality = editPersonaPersonality.text;
                                    root.settings.personas = JSON.stringify(ps);

                                    // Refresh currentPersona if it was the one edited
                                    if (root.settings.currentPersonaId === editPersonaPopup.editingId) {
                                        var temp = root.settings.currentPersonaId;
                                        root.settings.currentPersonaId = "";
                                        root.settings.currentPersonaId = temp;
                                    }

                                    // Refresh model
                                    personasModel.clear();
                                    ps.forEach(p => personasModel.append(p));

                                    editPersonaPopup.close();
                                    root.personaEdited();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
