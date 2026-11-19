import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    property var settings
    property var config
    property var generateIdFn

    property string draftApiEndpoint: ""
    property string draftApiKey: ""
    property string draftSearxngUrl: ""
    property real draftTemperature: 0.7
    property bool draftSummarizeSearch: true
    property bool searxngExpanded: false
    property string saveStatus: ""

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
        root.loadDraft();
        personasModel.clear();
        var parsedPersonas = JSON.parse(root.settings.personas);
        parsedPersonas.forEach(persona => personasModel.append(persona));
    }

    function loadDraft() {
        root.draftApiEndpoint = root.settings.apiEndpoint || "";
        root.draftApiKey = root.settings.apiKey || "";
        root.draftSearxngUrl = root.settings.searxngUrl || "";
        root.draftTemperature = Number(root.settings.temperature);
        root.draftSummarizeSearch = root.settings.summarizeSearch;

        apiEndpointField.text = root.draftApiEndpoint;
        apiKeyField.text = root.draftApiKey;
        searxngUrlField.text = root.draftSearxngUrl;
        temperatureSlider.value = root.draftTemperature;
        root.saveStatus = "";
    }

    function markDirty() {
        root.saveStatus = "unsaved changes";
    }

    function saveSettings() {
        root.settings.apiEndpoint = root.draftApiEndpoint.trim();
        root.settings.apiKey = root.draftApiKey.trim();
        root.settings.searxngUrl = root.draftSearxngUrl.trim();
        root.settings.temperature = root.draftTemperature;
        root.settings.summarizeSearch = root.draftSummarizeSearch;

        root.config.apiEndpoint = root.settings.apiEndpoint;
        root.config.apiKey = root.settings.apiKey;
        root.config.searxngUrl = root.settings.searxngUrl;
        root.config.temperature = root.settings.temperature;
        root.config.summarizeSearch = root.settings.summarizeSearch;

        root.saveStatus = "settings saved";
        root.settingsUpdated();
    }

    background: Rectangle {
        radius: root.config.panelRadius
        color: root.config.surfaceColor
        border.color: root.config.outerBorderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.config.outerMargin
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 12

            Text {
                text: "settings"
                color: root.config.textMain
                font.family: root.config.fontFamily
                font.pixelSize: 23
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: root.config.controlRadius
                color: root.config.nestedSurfaceColor
                border.color: root.config.outerBorderColor
                border.width: 1
                scale: closeMouseArea.pressed ? 0.94 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }

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
                    text: "configuration"
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
                                text: "api endpoint"
                                color: root.config.textMuted
                                font.family: root.config.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            StyledTextField {
                                id: apiEndpointField
                                Layout.fillWidth: true
                                text: root.draftApiEndpoint
                                config: root.config
                                placeholderText: "http://..."
                                onTextEdited: {
                                    root.draftApiEndpoint = text;
                                    root.markDirty();
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "api key"
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
                                    text: root.draftApiKey
                                    config: root.config
                                    echoMode: showApiKey.checked ? TextInput.Normal : TextInput.Password
                                    onTextEdited: {
                                        root.draftApiKey = text;
                                        root.markDirty();
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
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "temperature"
                                    color: root.config.textMuted
                                    font.family: root.config.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.draftTemperature.toFixed(1)
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
                                value: root.draftTemperature

                                onMoved: {
                                    root.draftTemperature = value;
                                    root.markDirty();
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

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: searxngColumn.implicitHeight + 28
                    radius: root.config.cardRadius
                    color: root.config.surfaceColor
                    border.color: root.config.outerBorderColor
                    border.width: 1

                    ColumnLayout {
                        id: searxngColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: "searxng"
                                color: root.config.textMain
                                font.family: root.config.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Image {
                                width: 16
                                height: 16
                                source: root.searxngExpanded ? "chevron-up.svg" : "chevron-down.svg"
                                sourceSize: Qt.size(16, 16)
                                fillMode: Image.PreserveAspectFit
                            }

                            TapHandler {
                                onTapped: root.searxngExpanded = !root.searxngExpanded
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.searxngExpanded
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "searxng url"
                                    color: root.config.textMuted
                                    font.family: root.config.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                StyledTextField {
                                    id: searxngUrlField
                                    Layout.fillWidth: true
                                    text: root.draftSearxngUrl
                                    config: root.config
                                    placeholderText: "http://localhost:8080"
                                    onTextEdited: {
                                        root.draftSearxngUrl = text;
                                        root.markDirty();
                                    }
                                }
                            }

                            CheckBox {
                                id: summarizeSearch
                                text: "summarize search results"
                                checked: root.draftSummarizeSearch

                                onToggled: {
                                    root.draftSummarizeSearch = checked;
                                    root.markDirty();
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
                        }
                    }
                }

                Text {
                    text: "personas"
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
                                        text: "active"
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
                                    text: "select"
                                    visible: root.settings.currentPersonaId !== model.id
                                    config: root.config
                                    onClicked: root.personaSelected(model.id)
                                }

                                RetroButton {
                                    text: "edit"
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
                                    text: "delete"
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
                    text: "+ add persona"
                    Layout.fillWidth: true
                    config: root.config
                    onClicked: {
                        newPersonaSystem.text = "You are a helpful assistant. System Info:\n- OS: {os}\n- Kernel: {kernel}\n- DE: {de}\n- User: {user}\n- Host: {hostname}\n- Time: {date time}";
                      addPersonaPopup.open();
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: root.saveStatus
                color: root.saveStatus === "settings saved" ? root.config.accent1 : root.config.textMuted
                font.family: root.config.fontFamily
                font.pixelSize: 12
            }

            RetroButton {
                text: "save"
                config: root.config
                Layout.preferredHeight: 38
                onClicked: root.saveSettings()
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
                    text: "add persona"
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
                    text: "system prompt"
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
                            placeholderText: "system prompt"
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
                    text: "personality prompt (optional)"
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
                            placeholderText: "personality prompt"
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
                        text: "cancel"
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
                            placeholderText: "personality prompt"
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
