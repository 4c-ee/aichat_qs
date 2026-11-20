import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.settings
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "MessageFormatter.js" as MessageFormatter

PanelWindow {
    id: root

    Config {
        id: config
    }

    readonly property alias panelConfig: config
    readonly property alias settingsStore: settings
    readonly property alias sessionsModelValue: sessionsModel
    readonly property alias sessionManager: sessionManager

    signal settingsPanelRequested()
    signal chatListPanelRequested()
    signal slideFinished(bool opened)

    ApiClient {
        id: apiClient
        onModelsReceived: (models) => {
            root.cachedModelsList = models;
            root.refreshModelFilter();
            root.cachedModelsEndpoint = settings.apiEndpoint.trim();
            root.cachedModelsKey = settings.apiKey.trim();
            root.modelsFetched = true;
            root.modelPickerStatus = models.length === 0 ? "No models returned by this endpoint." : "";
        }
        onModelsFailed: (error) => {
            root.modelsFetched = false;
            root.cachedModelsList = [];
            root.refreshModelFilter();
            root.modelPickerStatus = error;
        }
        onResponseReceived: (response, reasoning) => {
            root.isLoading = false;
            var wasAtEnd = chatView.atYEnd;
            var assistantMsg = { role: "assistant", content: response };
            if (reasoning) assistantMsg.reasoning = reasoning;
            root.messageHistory = [...root.messageHistory, assistantMsg];
            chatModel.append({
                sender: "ai",
                message: response,
                thinking: reasoning || "",
                historyIndex: root.messageHistory.length - 1,
                toolName: "",
                toolInput: "",
                toolOutput: "",
                toolStatus: ""
            });
            root.assistantResponseStarted = false;
            if (wasAtEnd) chatView.positionViewAtEnd();
        }
        onResponseChunk: (chunk) => {
            var wasAtEnd = chatView.atYEnd;
            root.assistantResponseStarted = true;
            if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).sender === "ai") {
                var lastIndex = chatModel.count - 1;
                var lastItem = chatModel.get(lastIndex);
                chatModel.setProperty(lastIndex, "message", lastItem.message + chunk);
            } else {
                chatModel.append({
                    sender: "ai",
                    message: chunk,
                    thinking: "",
                    historyIndex: -1,
                    toolName: "",
                    toolInput: "",
                    toolOutput: "",
                    toolStatus: ""
                });
            }
            if (wasAtEnd) chatView.positionViewAtEnd();
        }
        onThinkingChunk: (chunk) => {
            var wasAtEnd = chatView.atYEnd;
            root.assistantResponseStarted = true;
            if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).sender === "ai") {
                var lastIndex = chatModel.count - 1;
                var lastItem = chatModel.get(lastIndex);
                chatModel.setProperty(lastIndex, "thinking", (lastItem.thinking || "") + chunk);
            } else {
                chatModel.append({
                    sender: "ai",
                    message: "",
                    thinking: chunk,
                    historyIndex: -1,
                    toolName: "",
                    toolInput: "",
                    toolOutput: "",
                    toolStatus: ""
                });
            }
            if (wasAtEnd) chatView.positionViewAtEnd();
        }
        onRequestStopped: {
            root.isLoading = false;
            root.savePartialAssistantMessage();
        }
        onStreamingFinished: {
            root.isLoading = false;
            root.savePartialAssistantMessage();
        }
        onErrorOccurred: (error) => {
            root.isLoading = false;
            root.savePartialAssistantMessage();
            var wasAtEnd = chatView.atYEnd;
            chatModel.append({
                sender: "system",
                message: "Error: " + error,
                historyIndex: -1,
                toolName: "",
                toolInput: "",
                toolOutput: "",
                toolStatus: ""
            });
            if (wasAtEnd) chatView.positionViewAtEnd();
        }
    }

    ApiClient {
        id: backgroundApiClient
    }

    // The legacy custom-tool implementation is retained for later replacement,
    // but it is intentionally disconnected from response handling and prompts.
    ToolExecutor {
        id: toolExecutor
        chatModel: chatModel
        settings: settings
        config: config
        backgroundApiClient: backgroundApiClient
    }

    anchors {
        left: true
        top: true
        bottom: true
    }

    implicitWidth: config.panelWidth

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Match this namespace in a Hyprland layer rule to enable compositor blur.
    WlrLayershell.namespace: "aichat_qs"
    exclusiveZone: 0

    color: "transparent"

    // Quickshell's background effect requests a compositor-backed blur region.
    // The region follows the rounded panel while it slides in and out.
    BackgroundEffect.blurRegion: Region {
        item: container
        radius: config.panelRadius
    }

    property bool opened: true
    visible: true
    property bool isLoading: false
    property var attachments: []
    property string currentSessionId: ""
    property string cachedModelsEndpoint: ""
    property string cachedModelsKey: ""
    property var cachedModelsList: []
    property bool modelsFetched: false
    property string modelPickerStatus: ""
    property string modelFilterText: ""
    property bool assistantResponseStarted: false

    function openModelPicker() {
        if (modelPickerPopup.opened) {
            modelPickerPopup.close();
            return;
        }

        root.modelFilterText = "";
        modelPickerPopup.open();
        modelFilterField.forceActiveFocus();
        var endpoint = settings.apiEndpoint.trim();
        var key = settings.apiKey.trim();
        if (root.cachedModelsEndpoint !== endpoint || root.cachedModelsKey !== key || !root.modelsFetched) {
            filteredModelsModel.clear();
            root.cachedModelsList = [];
            root.refreshModelFilter();
            root.modelsFetched = false;
            root.modelPickerStatus = "Loading models...";
            apiClient.getModels(endpoint, key);
        } else {
            console.log("Using cached models list");
        }
    }

    function refreshModelFilter() {
        filteredModelsModel.clear();
        var filter = root.modelFilterText.trim().toLowerCase();
        root.cachedModelsList.forEach(modelId => {
            var modelName = String(modelId);
            if (filter === "" || modelName.toLowerCase().indexOf(filter) !== -1) {
                filteredModelsModel.append({
                    modelId: modelName,
                    displayName: modelName
                });
            }
        });
    }

    onModelFilterTextChanged: root.refreshModelFilter()

    property var currentPersona: null

    function computeCurrentPersona() {
        var ps = JSON.parse(settings.personas);
        currentPersona = ps.find(p => p.id === settings.currentPersonaId) || ps[0];
    }

    property bool systemInfoReady: false
    property var systemInfoMap: ({})

    function resolveSystemPrompt(systemText) {
        if (!systemText) return "";
        var text = systemText;
        var info = root.systemInfoMap || {};

        var dateVal = info.DATE || "";
        var userVal = info.USER || "";
        var hostVal = info.HOSTNAME || "";
        var osVal = info.OS || "";
        var deVal = info.DE || "N/A";
        var kernelVal = info.KERNEL || "";

        text = text.replace(/\{date time\}/gi, dateVal)
                   .replace(/\{datetime\}/gi, dateVal)
                   .replace(/\{date\}/gi, dateVal)
                   .replace(/\{user\}/gi, userVal)
                   .replace(/\{hostname\}/gi, hostVal)
                   .replace(/\{os\}/gi, osVal)
                   .replace(/\{de\}/gi, deVal)
                   .replace(/\{desktop\}/gi, deVal)
                   .replace(/\{kernel\}/gi, kernelVal);

        return MessageFormatter.stripLegacyToolInstructions(text);
    }

    // Remove data produced by the disconnected legacy text-tool protocol from
    // histories that were saved before the protocol was unhooked.
    function sanitizeLegacyToolHistory(history) {
        var cleaned = [];
        if (!history) return cleaned;

        history.forEach(function(msg) {
            if (!msg) return;

            if (msg.role === "system") {
                cleaned.push({
                    role: "system",
                    content: MessageFormatter.stripLegacyToolInstructions(msg.content)
                });
                return;
            }

            if (msg.role === "assistant" && typeof msg.content === "string") {
                var assistantContent = MessageFormatter.stripLegacyToolCall(msg.content);
                if (assistantContent === "") return;

                var assistantMessage = { role: "assistant", content: assistantContent };
                if (msg.reasoning) assistantMessage.reasoning = msg.reasoning;
                cleaned.push(assistantMessage);
                return;
            }

            if (msg.role === "user" && typeof msg.content === "string"
                    && msg.content.indexOf("TOOL RESULT:") === 0) {
                return;
            }

            cleaned.push(msg);
        });

        return cleaned;
    }

    function fetchSystemInfo() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        proc.command = ["sh", "-c", "echo 'DATE:' $(date); echo 'USER:' $USER; echo 'HOSTNAME:' $HOSTNAME; uname -r | sed 's/^/KERNEL: /'; cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | sed 's/\"//g' | sed 's/^/OS: /'; echo $XDG_CURRENT_DESKTOP | grep -v '^$' | sed 's/^/DE: /'"];

        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
        proc.stdout = collector;

        collector.streamFinished.connect(function() {
            var lines = collector.text.split('\n');
            var info = {};
            lines.forEach(function(line) {
                var parts = line.split(':', 2);
                if (parts.length === 2) {
                    var key = parts[0].trim();
                    var value = parts[1].trim();
                    if (key && value) info[key] = value;
                }
            });

            var infoParts = [];
            if (info.DATE) infoParts.push("Current Date/Time: " + info.DATE);
            if (info.USER) infoParts.push("User: " + info.USER);
            if (info.HOSTNAME) infoParts.push("Hostname: " + info.HOSTNAME);
            if (info.OS) infoParts.push("OS: " + info.OS);
            if (info.DE) infoParts.push("Desktop Environment: " + info.DE);
            if (info.KERNEL) infoParts.push("Kernel: " + info.KERNEL);

            root.systemInfoMap = info;
            root.systemInfoReady = true;

            if (currentSessionId === "") {
                var session = sessionManager.createNewSession();
                currentSessionId = session.id;
                root.messageHistory = session.history;
            } else if (messageHistory.length > 0 && messageHistory[0].role === "system") {
                var resolvedSystem = resolveSystemPrompt(currentPersona.system) + (currentPersona.personality ? "\n\n" + currentPersona.personality : "");
                if (messageHistory[0].content !== resolvedSystem) {
                    messageHistory[0].content = resolvedSystem;
                    sessionManager.saveCurrentSession(messageHistory);
                }
            }
            proc.destroy();
        });

        proc.running = true;
    }

    SessionManager {
        id: sessionManager
        settings: settings
        currentSessionId: root.currentSessionId
        config: config
        resolveSystemPromptFn: root.resolveSystemPrompt
        currentPersona: root.currentPersona
    }

    Settings {
        id: settings
        location: StandardPaths.writableLocation(StandardPaths.AppDataLocation) + "/history.conf"
        category: "History"
        property string savedSessions: "[]"
        property string lastModel: ""
        property string lastSessionId: ""
        property string personas: '[{"id":"default","name":"Assistant","system":"You are a helpful assistant. System Info:\\n- OS: {os}\\n- Kernel: {kernel}\\n- DE: {de}\\n- User: {user}\\n- Host: {hostname}\\n- Time: {date time}","personality":""}]'
        property string currentPersonaId: "default"
        property string apiEndpoint: "http://localhost:11434/v1"
        property string apiKey: ""
        property real temperature: 0.7
        property string searxngUrl: "http://localhost:8080"
        property bool summarizeSearch: true
    }

    onCurrentPersonaChanged: {
        if (messageHistory.length > 0 && messageHistory[0].role === "system") {
            var newSystem = resolveSystemPrompt(currentPersona.system) + (currentPersona.personality ? "\n\n" + currentPersona.personality : "");
            messageHistory[0].content = newSystem;
            sessionManager.saveCurrentSession(messageHistory);
        }
    }

    function generateId() {
        return MessageFormatter.generateId();
    }

    function saveCurrentSession() {
        sessionManager.saveCurrentSession(messageHistory);
    }

    function rebuildChatModel(history) {
        chatModel.clear();
        history.forEach((msg, index) => {
            if (msg.role !== "user" && msg.role !== "assistant")
                return;

            chatModel.append({
                sender: msg.role === "user" ? "you" : "ai",
                message: MessageFormatter.contentToString(msg.content),
                thinking: msg.reasoning || "",
                historyIndex: index,
                toolName: "",
                toolInput: "",
                toolOutput: "",
                toolStatus: ""
            });
        });
        chatView.positionViewAtEnd();
    }

    function retryMessage(historyIndex) {
        if (root.isLoading || historyIndex < 0 || historyIndex >= root.messageHistory.length)
            return;

        var userMessage = root.messageHistory[historyIndex];
        if (!userMessage || userMessage.role !== "user")
            return;

        var retryHistory = root.messageHistory.slice(0, historyIndex + 1);
        root.messageHistory = retryHistory;
        root.rebuildChatModel(retryHistory);
        root.assistantResponseStarted = false;
        root.isLoading = true;
        apiClient.sendMessage(
            settings.apiEndpoint,
            settings.apiKey,
            config.modelName,
            root.messageHistory,
            config.enableStreaming,
            config.temperature
        );
    }

    function forkMessage(historyIndex) {
        if (root.isLoading || historyIndex < 0 || historyIndex >= root.messageHistory.length)
            return;

        var assistantMessage = root.messageHistory[historyIndex];
        if (!assistantMessage || assistantMessage.role !== "assistant")
            return;

        var forkHistory = root.messageHistory.slice(0, historyIndex + 1);
        var forkId = root.generateId();
        currentSessionId = forkId;
        settings.lastSessionId = forkId;
        root.messageHistory = forkHistory;
        root.rebuildChatModel(forkHistory);
        sessionManager.saveCurrentSession(forkHistory);
        updateSessionsModel();
    }

    function loadSession(id) {
        var session = sessionManager.loadSession(id);
        if (session) {
            currentSessionId = id;
            settings.lastSessionId = id;
            var sanitizedHistory = root.sanitizeLegacyToolHistory(session.history);
            root.messageHistory = sanitizedHistory;

            if (session.modelName) {
                config.modelName = session.modelName;
                settings.lastModel = session.modelName;
            }
            if (session.temperature !== undefined) {
                config.temperature = session.temperature;
                settings.temperature = session.temperature;
            }
            if (session.personaId) {
                settings.currentPersonaId = session.personaId;
                computeCurrentPersona();
            }

            root.rebuildChatModel(sanitizedHistory);
        }
    }

    function createNewSession() {
        var session = sessionManager.createNewSession();
        currentSessionId = session.id;
        root.messageHistory = session.history;
        chatModel.clear();
        sessionManager.saveCurrentSession(messageHistory);
        updateSessionsModel();
    }

    function updateSessionsModel() {
        var sessions = JSON.parse(settings.savedSessions);

        // Reconcile instead of clearing the model so ListView can animate the
        // removed conversation and displaced conversations moving upward.
        for (var i = sessionsModel.count - 1; i >= 0; i--) {
            var existing = sessionsModel.get(i);
            var stillExists = sessions.some(session => session.id === existing.id);
            if (!stillExists)
                sessionsModel.remove(i);
        }

        sessions.forEach((session, targetIndex) => {
            var currentIndex = -1;
            for (var i = 0; i < sessionsModel.count; i++) {
                if (sessionsModel.get(i).id === session.id) {
                    currentIndex = i;
                    break;
                }
            }

            if (currentIndex === -1) {
                sessionsModel.append(session);
            } else {
                if (currentIndex !== targetIndex)
                    sessionsModel.move(currentIndex, targetIndex, 1);

                var current = sessionsModel.get(targetIndex);
                if (current.title !== session.title)
                    sessionsModel.setProperty(targetIndex, "title", session.title);
            }
        });
    }

    Component.onCompleted: {
        config.temperature = settings.temperature;
        computeCurrentPersona();

        if (settings.lastModel !== "") {
            config.modelName = settings.lastModel;
        }

        try {
            // Remove legacy text-tool instructions from saved personas without
            // deleting the rest of a user's prompt.
            var ps = JSON.parse(settings.personas);
            var personasChanged = false;
            ps.forEach(function(persona) {
                var sanitizedPrompt = MessageFormatter.stripLegacyToolInstructions(persona.system || "");
                if (sanitizedPrompt !== persona.system) {
                    persona.system = sanitizedPrompt;
                    personasChanged = true;
                }
            });
            if (personasChanged) {
                settings.personas = JSON.stringify(ps);
            }

            // Clean old chat histories as well, so disconnected tool output is
            // not sent back to the endpoint as prompt context.
            var sessions = JSON.parse(settings.savedSessions);
            var sessionsChanged = false;
            sessions.forEach(function(session) {
                var sanitizedHistory = root.sanitizeLegacyToolHistory(session.history);
                if (JSON.stringify(sanitizedHistory) !== JSON.stringify(session.history)) {
                    session.history = sanitizedHistory;
                    sessionsChanged = true;
                }
            });
            if (sessionsChanged) {
                settings.savedSessions = JSON.stringify(sessions);
            }
        } catch(e) {
            console.error("Failed to migrate legacy tool data:", e);
        }

        updateSessionsModel();

        if (settings.lastSessionId !== "") {
            loadSession(settings.lastSessionId);
        }

        fetchSystemInfo();
    }

    onMessageHistoryChanged: {
        sessionManager.saveCurrentSession(messageHistory);
        updateSessionsModel();
    }

    onOpenedChanged: {
        if (opened) {
            root.visible = true;
            inputArea.forceFocus();
        }
    }

    function formatMessage(text) {
        return MessageFormatter.formatMessage(text);
    }

    function savePartialAssistantMessage() {
        if (!root.assistantResponseStarted || chatModel.count === 0)
            return;

        var lastIndex = chatModel.count - 1;
        var lastItem = chatModel.get(lastIndex);
        if (lastItem.sender !== "ai")
            return;

        var assistantMsg = { role: "assistant", content: lastItem.message };
        if (lastItem.thinking) assistantMsg.reasoning = lastItem.thinking;
        root.messageHistory = [...root.messageHistory, assistantMsg];
        chatModel.setProperty(lastIndex, "historyIndex", root.messageHistory.length - 1);
        root.assistantResponseStarted = false;
    }

    function processAttachments(files, callback) {
        console.log("Processing attachments:", files.length);
        if (files.length === 0) {
            callback([]);
            return;
        }

        var results = new Array(files.length);
        var completed = 0;

        function checkCompletion() {
            completed++;
            console.log("Attachment progress:", completed, "/", files.length);
            if (completed === files.length) {
                console.log("All attachments processed. Count:", results.filter(r => r !== undefined).length);
                callback(results.filter(r => r !== undefined));
            }
        }

        files.forEach((file, index) => {
            console.log("Processing file:", file);
            if (file.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
                var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
                proc.command = ["base64", "-w", "0", file];

                var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
                proc.stdout = collector;

                var errCollector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
                proc.stderr = errCollector;
                errCollector.streamFinished.connect(function() {
                    if (errCollector.text !== "") console.error("Image process error for " + file + ":", errCollector.text);
                });

                collector.streamFinished.connect(function() {
                    var encodedData = collector.text.trim();
                    if (encodedData !== "") {
                        var mimeType = "image/jpeg";
                        if (file.match(/\.png$/i)) mimeType = "image/png";
                        else if (file.match(/\.gif$/i)) mimeType = "image/gif";
                        else if (file.match(/\.webp$/i)) mimeType = "image/webp";

                        console.log("Encoded image:", file, "size:", encodedData.length);
                        results[index] = {
                            type: "image_url",
                            image_url: {
                                url: "data:" + mimeType + ";base64," + encodedData
                            }
                        };
                    } else {
                        console.error("Image base64 encoding returned empty for:", file);
                    }

                    checkCompletion();
                    proc.destroy();
                });

                proc.running = true;
            } else if (file.match(/\.(wav|mp3|ogg|m4a)$/i)) {
                var procAudio = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
                procAudio.command = ["base64", "-w", "0", file];

                var collectorAudio = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', procAudio);
                procAudio.stdout = collectorAudio;

                var errCollectorAudio = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', procAudio);
                procAudio.stderr = errCollectorAudio;
                errCollectorAudio.streamFinished.connect(function() {
                    if (errCollectorAudio.text !== "") {
                        console.error("Audio process error:", errCollectorAudio.text);
                    }
                });

                collectorAudio.streamFinished.connect(function() {
                    if (collectorAudio.text !== "") {
                        var format = "wav";
                        if (file.match(/\.mp3$/i)) format = "mp3";
                        else if (file.match(/\.ogg$/i)) format = "ogg";
                        else if (file.match(/\.m4a$/i)) format = "m4a";

                        results[index] = {
                            type: "input_audio",
                            input_audio: {
                                data: collectorAudio.text.trim(),
                                format: format
                            }
                        };
                    }

                    checkCompletion();
                    procAudio.destroy();
                });

                procAudio.running = true;
            } else {
                var procDoc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
                procDoc.command = ["cat", file];

                var collectorDoc = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', procDoc);
                procDoc.stdout = collectorDoc;

                var errCollectorDoc = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', procDoc);
                procDoc.stderr = errCollectorDoc;
                errCollectorDoc.streamFinished.connect(function() {
                    if (errCollectorDoc.text !== "") console.error("Doc process error:", errCollectorDoc.text);
                });

                collectorDoc.streamFinished.connect(function() {
                    if (collectorDoc.text !== "") {
                        var fileName = file.split('/').pop();
                        results[index] = {
                            type: "text",
                            text: "\n--- Attached File: " + fileName + " ---\n" + collectorDoc.text + "\n--- End Attachment ---"
                        };
                    }

                    checkCompletion();
                    procDoc.destroy();
                });

                procDoc.running = true;
            }
        });
    }

    property var messageHistory: [
        { role: "system", content: "You are a helpful assistant." }
    ]

    ListModel { id: chatModel }
    ListModel { id: sessionsModel }
    ListModel { id: filteredModelsModel }

    Popup {
        id: modelPickerPopup
        parent: inputArea.modelPickerButton
        x: 0
        y: -height - 6
        width: Math.min(300, root.implicitWidth - 32)
        height: Math.min(440, Math.max(110, 48 + filteredModelsModel.count * 38
            + (root.modelPickerStatus !== "" ? 48 : 12)))
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            radius: config.controlRadius
            color: config.surfaceColor
            border.color: config.outerBorderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 4

            StyledTextField {
                id: modelFilterField
                Layout.fillWidth: true
                config: config
                placeholderText: "Filter models..."
                text: root.modelFilterText
                onTextEdited: root.modelFilterText = text
            }

            Text {
                Layout.fillWidth: true
                visible: root.modelPickerStatus !== ""
                text: root.modelPickerStatus
                color: config.dangerColor
                font.family: config.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.modelFilterText.trim() !== ""
                    && root.cachedModelsList.length > 0
                    && filteredModelsModel.count === 0
                text: "No models match this filter."
                color: config.textMuted
                font.family: config.fontFamily
                font.pixelSize: 12
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: filteredModelsModel
                clip: true
                spacing: 3

                delegate: ItemDelegate {
                    id: modelDelegate
                    width: ListView.view.width
                    height: 35
                    padding: 10

                    contentItem: Text {
                        text: model.displayName
                        color: modelDelegate.highlighted
                            ? config.accent1Hover
                            : (model.modelId === config.modelName ? config.accent1 : config.textMain)
                        font.family: config.fontFamily
                        font.pixelSize: 13
                        font.weight: modelDelegate.highlighted || model.modelId === config.modelName
                            ? Font.DemiBold
                            : Font.Normal
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        radius: config.controlRadius
                        color: modelDelegate.hovered ? config.accent1Hover : "transparent"
                    }

                    onClicked: {
                        config.modelName = model.modelId;
                        settings.lastModel = model.modelId;
                        modelPickerPopup.close();
                    }
                }
            }
        }
    }

    Rectangle {
        id: container
        width: parent.width
        height: parent.height
        color: config.surfaceColor
        radius: config.panelRadius
        border.color: config.outerBorderColor
        border.width: 2
        clip: true

        x: root.opened ? 0 : -root.implicitWidth
        Behavior on x {
            NumberAnimation {
                id: slideAnimation
                duration: 300
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running) {
                        if (!root.opened)
                            root.visible = false;
                        root.slideFinished(root.opened);
                    }
                }
            }
        }

        DropArea {
            anchors.fill: parent
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    var newAttachments = [...root.attachments];
                    for (var i = 0; i < drop.urls.length; i++) {
                        var url = drop.urls[i].toString();
                        if (url.startsWith("file://")) {
                            url = url.substring(7);
                        }
                        if (newAttachments.indexOf(url) === -1) {
                            newAttachments.push(url);
                        }
                    }
                    root.attachments = newAttachments;
                }
            }
        }

        Item {
            id: panelForeground
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: config.outerMargin
                spacing: 12

                HeaderBar {
                    Layout.fillWidth: true
                    currentPersona: root.currentPersona
                    settings: settings
                    config: config

                    onNewChatRequested: root.createNewSession()
                    onSettingsPanelRequested: root.settingsPanelRequested()
                    onChatListPanelRequested: root.chatListPanelRequested()
                }

                ChatArea {
                    id: chatView
                    chatModel: chatModel
                    config: config
                    isLoading: root.isLoading
                    formatMessageFn: root.formatMessage

                    onRetryRequested: (historyIndex) => root.retryMessage(historyIndex)
                    onForkRequested: (historyIndex) => root.forkMessage(historyIndex)
                }

                InputArea {
                    id: inputArea
                    config: config
                    isLoading: root.isLoading
                    modelPickerOpen: modelPickerPopup.opened
                    attachments: root.attachments

                    onAttachmentAdded: (filePath) => {
                        root.attachments = [...root.attachments, filePath];
                    }
                    onAttachmentRemoved: (index) => {
                        var newAttachments = [...root.attachments];
                        newAttachments.splice(index, 1);
                        root.attachments = newAttachments;
                    }

                    onSendRequested: (text, attachments) => {
                        root.processAttachments(attachments, function(processedAttachments) {
                            var userMessage = { role: "user", content: text };
                            if (processedAttachments.length > 0) {
                                userMessage.content = [
                                    { type: "text", text: text },
                                    ...processedAttachments
                                ];
                            }
                            root.messageHistory = [...root.messageHistory, userMessage];
                            chatModel.append({
                                sender: "you",
                                message: text,
                                thinking: "",
                                historyIndex: root.messageHistory.length - 1,
                                toolName: "",
                                toolInput: "",
                                toolOutput: "",
                                toolStatus: ""
                            });
                            root.attachments = [];
                            root.assistantResponseStarted = false;
                            root.isLoading = true;
                            chatView.positionViewAtEnd();
                            apiClient.sendMessage(
                                settings.apiEndpoint,
                                settings.apiKey,
                                config.modelName,
                                root.messageHistory,
                                config.enableStreaming,
                                config.temperature
                            );
                        });
                    }
                    onStopRequested: () => {
                        apiClient.stop();
                    }
                    onModelPickerRequested: () => {
                        root.openModelPicker();
                    }
                }
            }
        }

    }
}
