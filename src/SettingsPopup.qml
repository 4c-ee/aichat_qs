import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    property var settings
    property var config
    property var generateIdFn

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
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        personasModel.clear();
        var parsedPersonas = JSON.parse(root.settings.personas);
        parsedPersonas.forEach(persona => personasModel.append(persona));
    }

    background: Rectangle {
        radius: root.config.panelRadius
        color: root.config.surfaceColor
        border.color: root.config.outerBorderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Settings"
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 23
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Connection, model behavior, and personas"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: root.config.controlRadius
                color: root.config.nestedSurfaceColor
                border.color: root.config.outerBorderColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: closeMouseArea.containsMouse ? root.config.accent1Hover : root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 23
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        ScrollView {
            id: settingsScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: settingsScrollView.availableWidth
                spacing: 16

                Text {
                    text: "CONFIGURATION"
                    color: root.config.accent1
                    font.family: root.config.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: configurationColumn.implicitHeight + 28
                    radius: root.config.cardRadius
                    color: root.config.surfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1

                    ColumnLayout {
                        id: configurationColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 13

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "API endpoint"
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            StyledTextField {
                                Layout.fillWidth: true
                                text: root.settings.apiEndpoint
                                config: root.config
                                placeholderText: "http://..."
                                onTextChanged: {
                                    root.settings.apiEndpoint = text;
                                    root.config.apiEndpoint = text;
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "API key"
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledTextField {
                                    id: apiKeyField
                                    Layout.fillWidth: true
                                    text: root.settings.apiKey
                                    config: root.config
                                    echoMode: showApiKey.checked ? TextInput.Normal : TextInput.Password
                                    onTextChanged: {
                                        root.settings.apiKey = text;
                                        root.config.apiKey = text;
                                    }
                                }

                                CheckBox {
                                    id: showApiKey
                                    text: "Show"

                                    indicator: Rectangle {
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        x: 0
                                        y: showApiKey.height / 2 - height / 2
                                        radius: 5
                                        color: root.config.nestedSurfaceColor
                                        border.color: showApiKey.checked ? root.config.accent1 : root.config.outerBorderColor
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            visible: showApiKey.checked
                                            color: root.config.accent1
                                            font.family: root.config.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }
                                    }

                                    contentItem: Text {
                                        text: showApiKey.text
                                        color: root.config.textMain
                                        font.family: root.config.fontFamily
                                        font.pixelSize: 13
                                        leftPadding: 25
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "SearXNG URL"
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            StyledTextField {
                                Layout.fillWidth: true
                                text: root.settings.searxngUrl
                                config: root.config
                                placeholderText: "http://localhost:8080"
                                onTextChanged: {
                                    root.settings.searxngUrl = text;
                                    root.config.searxngUrl = text;
                                }
                            }
                        }

                        CheckBox {
                            id: summarizeSearch
                            text: "Summarize search results"
                            checked: root.settings.summarizeSearch

                            onCheckedChanged: {
                                root.settings.summarizeSearch = checked;
                                root.config.summarizeSearch = checked;
                            }

                            indicator: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                x: 0
                                y: summarizeSearch.height / 2 - height / 2
                                radius: 5
                                color: root.config.nestedSurfaceColor
                                border.color: summarizeSearch.checked ? root.config.accent1 : root.config.outerBorderColor
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: summarizeSearch.checked
                                    color: root.config.accent1
                                    font.family: root.config.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            contentItem: Text {
                                text: summarizeSearch.text
                                color: root.config.textMain
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                leftPadding: 25
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Temperature"
                                    color: root.config.textMuted
                                    font.family: root.config.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.settings.temperature.toFixed(1)
                                    color: root.config.accent2
                                    font.family: root.config.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                            }

                            Slider {
                                id: temperatureSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 2
                                stepSize: 0.1
                                value: root.settings.temperature

                                onMoved: {
                                    root.settings.temperature = value;
                                    root.config.temperature = value;
                                }

                                handle: Rectangle {
                                    x: temperatureSlider.visualPosition * (temperatureSlider.availableWidth - width)
                                    y: temperatureSlider.topPadding + (temperatureSlider.availableHeight - height) / 2
                                    width: 17
                                    height: 17
                                    radius: 9
                                    color: root.config.accent1
                                    border.color: root.config.accent1Hover
                                    border.width: 1
                                }

                                background: Rectangle {
                                    x: temperatureSlider.leftPadding
                                    y: temperatureSlider.topPadding + (temperatureSlider.availableHeight - height) / 2
                                    width: temperatureSlider.availableWidth
                                    height: 5
                                    radius: 3
                                    color: root.config.nestedSurfaceColor

                                    Rectangle {
                                        width: temperatureSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.config.accent1
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "PERSONAS"
                    color: root.config.accent1
                    font.family: root.config.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                ListView {
                    id: personasListView
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentHeight
                    interactive: false
                    model: ListModel { id: personasModel }
                    spacing: 9

                    delegate: Rectangle {
                        width: personasListView.width
                        implicitHeight: personaColumn.implicitHeight + 24
                        radius: root.config.cardRadius
                        color: root.config.surfaceColor
                        border.color: root.settings.currentPersonaId === model.id ? root.config.accent1 : root.config.outerBorderColor
                        border.width: 1

                        ColumnLayout {
                            id: personaColumn
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name
                                    color: root.config.textMain
                                    font.family: root.config.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    visible: root.settings.currentPersonaId === model.id
                                    Layout.preferredWidth: 62
                                    Layout.preferredHeight: 22
                                    radius: 8
                                    color: root.config.nestedSurfaceColor
                                    border.color: root.config.accent1
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "ACTIVE"
                                        color: root.config.accent1
                                        font.family: root.config.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.6
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "System: " + model.system.substring(0, 72) + (model.system.length > 72 ? "…" : "")
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 7

                                Item {
                                    Layout.fillWidth: true
                                }

                                RetroButton {
                                    text: "Select"
                                    visible: root.settings.currentPersonaId !== model.id
                                    config: root.config
                                    onClicked: root.personaSelected(model.id)
                                }

                                RetroButton {
                                    text: "Edit"
                                    config: root.config
                                    onClicked: {
                                        editPersonaPopup.editingId = model.id;
                                        editPersonaName.text = model.name;
                                        editPersonaSystem.text = model.system;
                                        editPersonaPersonality.text = model.personality || "";
                                        editPersonaPopup.open();
                                    }
                                }

                                RetroButton {
                                    text: "Delete"
                                    visible: model.id !== "default"
                                    config: root.config
                                    onClicked: {
                                        var parsedPersonas = JSON.parse(root.settings.personas);
                                        var index = parsedPersonas.findIndex(persona => persona.id === model.id);
                                        if (index !== -1) {
                                            parsedPersonas.splice(index, 1);
                                            root.settings.personas = JSON.stringify(parsedPersonas);
                                            if (root.settings.currentPersonaId === model.id)
                                                root.settings.currentPersonaId = "default";

                                            personasModel.clear();
                                            parsedPersonas.forEach(persona => personasModel.append(persona));
                                            root.personaDeleted();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RetroButton {
                    text: "+ Add persona"
                    Layout.fillWidth: true
                    config: root.config
                    onClicked: {
                        newPersonaSystem.text = "You are a helpful assistant. System Info:\n- OS: {os}\n- Kernel: {kernel}\n- DE: {de}\n- User: {user}\n- Host: {hostname}\n- Time: {date time}\n\n# Tool Use\nYou can call tools by outputting tool[\"(tool_name)\", \"input1\", \"input2\"].\nThe tool call MUST be at the end of your response.\n\nAvailable tools:\n- tool[\"search\", \"query\"]: Searches the web using SearXNG. Returns top results and text from the first 3.\n- tool[\"getpage\", \"url\", \"prompt\"]: Fetches a URL and uses a separate model to extract info based on the prompt.";
                        addPersonaPopup.open();
                    }
                }
            }
        }
    }

    DarkPopup {
        id: addPersonaPopup
        anchors.centerIn: parent
        width: Math.min(430, parent.width - 32)
        height: Math.min(560, parent.height - 32)

        ScrollView {
            id: addPersonaScrollView
            anchors.fill: parent
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: addPersonaScrollView.availableWidth
                spacing: 13

                Text {
                    text: "Add persona"
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                }

                StyledTextField {
                    id: newPersonaName
                    Layout.fillWidth: true
                    config: root.config
                    placeholderText: "Name"
                }

                Text {
                    text: "System prompt"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6

                        TextArea {
                            id: newPersonaSystem
                            width: parent.width
                            padding: 7
                            placeholderText: "System prompt"
                            color: root.config.textMain
                            placeholderTextColor: root.config.textMuted
                            selectionColor: root.config.accent2
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                Text {
                    text: "Personality prompt (optional)"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6

                        TextArea {
                            id: newPersonaPersonality
                            width: parent.width
                            padding: 7
                            placeholderText: "Personality prompt"
                            color: root.config.textMain
                            placeholderTextColor: root.config.textMuted
                            selectionColor: root.config.accent2
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    Item {
                        Layout.fillWidth: true
                    }

                    RetroButton {
                        text: "Cancel"
                        config: root.config
                        onClicked: addPersonaPopup.close()
                    }

                    RetroButton {
                        text: "Save"
                        config: root.config
                        onClicked: {
                            if (newPersonaName.text.trim() !== "") {
                                var parsedPersonas = JSON.parse(root.settings.personas);
                                parsedPersonas.push({
                                    id: root.generateIdFn(),
                                    name: newPersonaName.text.trim(),
                                    system: newPersonaSystem.text,
                                    personality: newPersonaPersonality.text
                                });
                                root.settings.personas = JSON.stringify(parsedPersonas);

                                personasModel.clear();
                                parsedPersonas.forEach(persona => personasModel.append(persona));

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

    DarkPopup {
        id: editPersonaPopup
        anchors.centerIn: parent
        width: Math.min(430, parent.width - 32)
        height: Math.min(560, parent.height - 32)

        property string editingId: ""

        ScrollView {
            id: editPersonaScrollView
            anchors.fill: parent
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: editPersonaScrollView.availableWidth
                spacing: 13

                Text {
                    text: "Edit persona"
                    color: root.config.textMain
                    font.family: root.config.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                }

                StyledTextField {
                    id: editPersonaName
                    Layout.fillWidth: true
                    config: root.config
                    placeholderText: "Name"
                }

                Text {
                    text: "System prompt"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 210
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6

                        TextArea {
                            id: editPersonaSystem
                            width: parent.width
                            padding: 7
                            placeholderText: "System prompt"
                            color: root.config.textMain
                            placeholderTextColor: root.config.textMuted
                            selectionColor: root.config.accent2
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                Text {
                    text: "Personality prompt (optional)"
                    color: root.config.textMuted
                    font.family: root.config.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: root.config.controlRadius
                    color: root.config.nestedSurfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6

                        TextArea {
                            id: editPersonaPersonality
                            width: parent.width
                            padding: 7
                            placeholderText: "Personality prompt"
                            color: root.config.textMain
                            placeholderTextColor: root.config.textMuted
                            selectionColor: root.config.accent2
                            font.family: root.config.fontFamily
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            background: null
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    Item {
                        Layout.fillWidth: true
                    }

                    RetroButton {
                        text: "Cancel"
                        config: root.config
                        onClicked: editPersonaPopup.close()
                    }

                    RetroButton {
                        text: "Save"
                        config: root.config
                        onClicked: {
                            if (editPersonaName.text.trim() !== "") {
                                var parsedPersonas = JSON.parse(root.settings.personas);
                                var index = parsedPersonas.findIndex(persona => persona.id === editPersonaPopup.editingId);
                                if (index !== -1) {
                                    parsedPersonas[index].name = editPersonaName.text.trim();
                                    parsedPersonas[index].system = editPersonaSystem.text;
                                    parsedPersonas[index].personality = editPersonaPersonality.text;
                                    root.settings.personas = JSON.stringify(parsedPersonas);

                                    if (root.settings.currentPersonaId === editPersonaPopup.editingId) {
                                        var selectedId = root.settings.currentPersonaId;
                                        root.settings.currentPersonaId = "";
                                        root.settings.currentPersonaId = selectedId;
                                    }

                                    personasModel.clear();
                                    parsedPersonas.forEach(persona => personasModel.append(persona));

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
