import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.settings
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "ApiClient.js" as ApiClientJs
import "MessageFormatter.js" as MessageFormatter

PanelWindow {
    id: root

    Config {
        id: config
    }

    ApiClient {
        id: apiClient
        onModelsReceived: (models) => {
            modelsModel.clear();
            models.forEach(m => modelsModel.append({name: m}));
            root.cachedModelsList = models;
            root.cachedModelsEndpoint = settings.apiEndpoint;
            root.cachedModelsKey = settings.apiKey;
        }
        onResponseReceived: (response, reasoning) => {
            root.isLoading = false;
            var wasAtEnd = chatView.atYEnd;
            chatModel.append({
                sender: "AI",
                message: response,
                thinking: reasoning || "",
                toolName: "",
                toolInput: "",
                toolOutput: "",
                toolStatus: ""
            });
            var lastIndex = chatModel.count - 1;
            root.messageHistory = [...root.messageHistory, { role: "assistant", content: response }];
            if (wasAtEnd) chatView.positionViewAtEnd();

            toolExecutor.checkForToolCall(lastIndex, response);
        }
        onResponseChunk: (chunk) => {
            var wasAtEnd = chatView.atYEnd;
            if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).sender === "AI") {
                var lastIndex = chatModel.count - 1;
                var lastItem = chatModel.get(lastIndex);
                chatModel.setProperty(lastIndex, "message", lastItem.message + chunk);
            } else {
                chatModel.append({
                    sender: "AI",
                    message: chunk,
                    thinking: "",
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
            if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).sender === "AI") {
                var lastIndex = chatModel.count - 1;
                var lastItem = chatModel.get(lastIndex);
                chatModel.setProperty(lastIndex, "thinking", (lastItem.thinking || "") + chunk);
            } else {
                    chatModel.append({
                    sender: "AI",
                    message: "",
                    thinking: chunk,
                    toolName: "",
                    toolInput: "",
                    toolOutput: "",
                    toolStatus: ""
                });
            }
            if (wasAtEnd) chatView.positionViewAtEnd();
        }
        onStreamingFinished: {
            root.isLoading = false;
            if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).sender === "AI") {
                var lastIndex = chatModel.count - 1;
                var lastItem = chatModel.get(lastIndex);
                root.messageHistory = [...root.messageHistory, { role: "assistant", content: lastItem.message }];

                toolExecutor.checkForToolCall(lastIndex, lastItem.message);
            }
        }
        onErrorOccurred: (error) => {
            root.isLoading = false;
            var wasAtEnd = chatView.atYEnd;
            chatModel.append({
                sender: "System",
                message: "Error: " + error,
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

    ToolExecutor {
        id: toolExecutor
        chatModel: chatModel
        settings: settings
        config: config
        backgroundApiClient: backgroundApiClient

        onToolCallFinished: (index, resultText) => {
            root.isLoading = true;
            root.messageHistory = [...root.messageHistory, { role: "user", content: "TOOL RESULT:\n\n" + resultText }];
            var cleanedHistory = MessageFormatter.stripReasoningFromHistory(root.messageHistory);
            apiClient.sendMessage(
                settings.apiEndpoint,
                settings.apiKey,
                config.modelName,
                cleanedHistory,
                config.enableStreaming,
                config.temperature
            );
        }
    }

    anchors {
        left: true
        top: true
        bottom: true
    }

    implicitWidth: config.panelWidth

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: 0

    color: "transparent"

    property bool opened: true
    visible: true
    property bool isLoading: false
    property var attachments: []
    property string currentSessionId: ""
    property string cachedModelsEndpoint: ""
    property string cachedModelsKey: ""
    property var cachedModelsList: []

    function openModelPicker() {
        modelPickerPopup.open();
        if (root.cachedModelsEndpoint !== settings.apiEndpoint || root.cachedModelsKey !== settings.apiKey || root.cachedModelsList.length === 0) {
            apiClient.getModels(settings.apiEndpoint, settings.apiKey);
        } else {
            console.log("Using cached models list");
        }
    }

    property var currentPersona: {
        var ps = JSON.parse(settings.personas);
        return ps.find(p => p.id === settings.currentPersonaId) || ps[0];
    }

    property string systemInfoString: ""
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

        return text;
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

            root.systemInfoString = infoParts.join("\n");
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
        property string personas: '[{"id":"default","name":"Assistant","system":"You are a helpful assistant. System Info:\\n- OS: {os}\\n- Kernel: {kernel}\\n- DE: {de}\\n- User: {user}\\n- Host: {hostname}\\n- Time: {date time}\\n\\n# Tool Use\\nYou can call tools by outputting tool[\\\"(tool_name)\\\", \\\"input1\\\", \\\"input2\\\"].\\nThe tool call MUST be at the end of your response.\\n\\nAvailable tools:\\n- tool[\\\"search\\\", \\\"query\\\"]: Searches the web using SearXNG. Returns top results and text from the first 3.\\n- tool[\\\"getpage\\\", \\\"url\\\", \\\"prompt\\\"]: Fetches a URL and uses a separate model to extract info based on the prompt.","personality":""}]'
        property string currentPersonaId: "default"
        property string apiEndpoint: "http://localhost:11434/v1"
        property string apiKey: "wawa"
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
        return Date.now().toString(36) + Math.random().toString(36).substring(2);
    }

    function saveCurrentSession() {
        sessionManager.saveCurrentSession(messageHistory);
    }

    function loadSession(id) {
        var session = sessionManager.loadSession(id);
        if (session) {
            currentSessionId = id;
            settings.lastSessionId = id;
            root.messageHistory = session.history;

            if (session.modelName) {
                config.modelName = session.modelName;
                settings.lastModel = session.modelName;
            }
            if (session.temperature !== undefined) {
                config.temperature = session.temperature;
            }
            if (session.personaId) {
                settings.currentPersonaId = session.personaId;
            }

            chatModel.clear();
            session.history.forEach(msg => {
                if (msg.role !== "system") {
                    var displayContent = MessageFormatter.contentToString(msg.content);

                    chatModel.append({
                        sender: msg.role === "user" ? "You" : "AI",
                        message: displayContent,
                        thinking: "",
                        toolName: "",
                        toolInput: "",
                        toolOutput: "",
                        toolStatus: ""
                    });
                }
            });
            chatView.positionViewAtEnd();
        }
    }

    function createNewSession() {
        var session = sessionManager.createNewSession();
        currentSessionId = session.id;
        root.messageHistory = session.history;
        chatModel.clear();
        sessionManager.saveCurrentSession(messageHistory);
    }

    function updateSessionsModel() {
        var sessions = JSON.parse(settings.savedSessions);
        sessionsModel.clear();
        sessions.forEach(s => sessionsModel.append(s));
    }

    Component.onCompleted: {
        config.apiEndpoint = settings.apiEndpoint;
        config.apiKey = settings.apiKey;
        config.temperature = settings.temperature;
        config.searxngUrl = settings.searxngUrl;
        config.summarizeSearch = settings.summarizeSearch;

        if (settings.lastModel !== "") {
            config.modelName = settings.lastModel;
        }

        try {
            var ps = JSON.parse(settings.personas);
            var defP = ps.find(p => p.id === "default");
            var toolInfo = "\n\n# Tool Use\nYou can call tools by outputting tool[\\\"(tool_name)\\\", \\\"input1\\\", \\\"input2\\\"].\nThe tool call MUST be at the end of your response.\n\nAvailable tools:\\n- tool[\\\"search\\\", \\\"query\\\"]: Searches the web using SearXNG. Returns top results and text from the first 3.\\n- tool[\\\"getpage\\\", \\\"url\\\", \\\"prompt\\\"]: Fetches a URL and uses a separate model to extract info based on the prompt.";

            if (defP) {
                var changed = false;
                if (defP.system === "You are a helpful assistant." || !defP.system.includes("{os}")) {
                    defP.system = "You are a helpful assistant. System Info:\n- OS: {os}\n- Kernel: {kernel}\n- DE: {de}\n- User: {user}\n- Host: {hostname}\n- Time: {date time}";
                    changed = true;
                }
                if (!defP.system.includes("tool[\"(tool_name)\"]") && !defP.system.includes("tool[\"search\", \"query\"]")) {
                    defP.system += toolInfo;
                    changed = true;
                }
                if (changed) {
                    settings.personas = JSON.stringify(ps);
                }
            }
        } catch(e) {
            console.error("Failed to migrate default persona:", e);
        }

        updateSessionsModel();

        if (settings.lastSessionId !== "") {
            loadSession(settings.lastSessionId);
        }

        fetchSystemInfo();
    }

    onMessageHistoryChanged: {
        sessionManager.saveCurrentSession(messageHistory);
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

    function stripReasoningFromHistory(history) {
        return MessageFormatter.stripReasoningFromHistory(history);
    }

    function contentToString(content) {
        return MessageFormatter.contentToString(content);
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
                                data: collectorAudio.text,
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
    ListModel { id: modelsModel }

    SideMenu {
        id: sideMenu
        settings: settings
        currentSessionId: root.currentSessionId
        sessionsModel: sessionsModel

        onLoadSessionRequested: (id) => root.loadSession(id)
        onNewChatRequested: root.createNewSession()
        onUpdateSessionsModelRequested: root.updateSessionsModel()
    }

    SettingsPopup {
        id: settingsPopup
        settings: settings
        config: config
        generateIdFn: root.generateId

        onPersonaSelected: (id) => {
            settings.currentPersonaId = id;
        }
    }

    Popup {
        id: modelPickerPopup
        x: parent.width / 2 - width / 2
        y: parent.height / 2 - height / 2
        width: 300
        height: Math.min(400, modelsModel.count * 30 + 10)
        padding: 5
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: "#1A1A1A"
            border.color: "#404040"
        }

        contentItem: ListView {
            model: modelsModel
            delegate: ItemDelegate {
                width: parent.width
                height: 30
                contentItem: Text {
                    text: name
                    color: "#c5c5c5"
                    font.family: "Monospace"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: hovered ? "#333333" : "transparent"
                }
                onClicked: {
                    config.modelName = name;
                    settings.lastModel = name;
                    modelPickerPopup.close();
                }
            }
            clip: true
        }
    }

    Rectangle {
        id: container
        width: parent.width
        height: parent.height
        color: "black"

        x: root.opened ? 0 : -root.implicitWidth
        Behavior on x {
            NumberAnimation {
                id: slideAnimation
                duration: 300
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running && !root.opened) {
                        root.visible = false;
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            HeaderBar {
                Layout.fillWidth: true
                currentPersona: root.currentPersona
                sideMenuOpen: sideMenu.isOpen
                settings: settings
                sideMenu: sideMenu

                onNewChatRequested: root.createNewSession()
                onSettingsRequested: settingsPopup.open()
            }

            ChatArea {
                id: chatView
                chatModel: chatModel
                config: config
                isLoading: root.isLoading
                formatMessageFn: root.formatMessage
            }

            InputArea {
                id: inputArea
                config: config
                isLoading: root.isLoading
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
                        root.attachments = [];
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