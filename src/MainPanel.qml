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
            
            checkForToolCall(lastIndex, response);
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
            // Finalize message history
            if (chatModel.count > 0 && chatModel.get(chatModel.count - 1).sender === "AI") {
                var lastIndex = chatModel.count - 1;
                var lastItem = chatModel.get(lastIndex);
                root.messageHistory = [...root.messageHistory, { role: "assistant", content: lastItem.message }];
                
                checkForToolCall(lastIndex, lastItem.message);
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
    
    anchors {
        left: true
        top: true
        bottom: true
    }
    
    implicitWidth: config.panelWidth
    
    // Stacking order
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: 0
    
    // Transparent window background
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
                createNewSession();
            } else if (messageHistory.length > 0 && messageHistory[0].role === "system") {
                var resolvedSystem = resolveSystemPrompt(currentPersona.system) + (currentPersona.personality ? "\n\n" + currentPersona.personality : "");
                if (messageHistory[0].content !== resolvedSystem) {
                    messageHistory[0].content = resolvedSystem;
                    saveCurrentSession();
                }
            }
            proc.destroy();
        });

        proc.running = true;
    }

    function checkForToolCall(index, content) {
        if (!content) return;

        var trimmed = content.trim();
        // Regex to match tool["name", "input1", "input2"]
        var match = trimmed.match(/tool\["([^"]+)"(?:,\s*"([^"]+)")?(?:,\s*"([^"]+)")?\]$/);

        if (match) {
            var toolName = match[1];
            var input1 = match[2];
            var input2 = match[3];

            if (toolName === "search") {
                executeSearch(index, input1);
            } else if (toolName === "getpage") {
                executeGetPage(index, input1, input2);
            }
        }
    }

    function truncateOutput(text, limit) {
        if (!text) return "";
        var l = limit || 500;
        if (text.length <= l) return text;
        return text.substring(0, l) + "... [truncated]";
    }

    function executeSearch(index, query) {
        chatModel.setProperty(index, "toolName", "search");
        chatModel.setProperty(index, "toolInput", "\"" + query + "\"");
        chatModel.setProperty(index, "toolStatus", "searching...");
        
        var xhr = new XMLHttpRequest();
        var url = settings.searxngUrl + "/search?format=json&q=" + encodeURIComponent(query);
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        processSearchResults(index, query, response.results || []);
                    } catch (e) {
                        chatModel.setProperty(index, "toolStatus", "error parsing results");
                        chatModel.setProperty(index, "toolOutput", e.message);
                    }
                } else {
                    chatModel.setProperty(index, "toolStatus", "error " + xhr.status);
                }
            }
        };
        xhr.send();
    }

    function processSearchResults(index, query, results) {
        if (results.length === 0) {
            finishToolCall(index, "No results found for: " + query);
            return;
        }
        
        var topResults = results.slice(0, 3);
        var otherResults = results.slice(3, 10);
        
        var fetchedContent = [];
        var completed = 0;
        
        chatModel.setProperty(index, "toolStatus", "fetching pages (0/" + topResults.length + ")...");
        
        if (topResults.length === 0) {
            finalizeSearch(index, query, [], otherResults);
            return;
        }

        topResults.forEach((res, i) => {
            fetchUrl(res.url, function(content) {
                fetchedContent[i] = {
                    title: res.title,
                    url: res.url,
                    content: content
                };
                completed++;
                chatModel.setProperty(index, "toolStatus", "fetching pages (" + completed + "/" + topResults.length + ")...");
                
                if (completed === topResults.length) {
                    finalizeSearch(index, query, fetchedContent, otherResults);
                }
            });
        });
    }

    function fetchUrl(url, callback) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        proc.command = ["curl", "-sL", "-m", "10", url];
        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
        proc.stdout = collector;
        
        collector.streamFinished.connect(function() {
            var html = collector.text;
            if (html.trim() === "") {
                callback("[Empty response]");
                proc.destroy();
                return;
            }
            
            var parseProc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
            parseProc.command = ["node", "src/htmlToText.js"];
            parseProc.stdinEnabled = true;
            
            var parseCollector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', parseProc);
            parseProc.stdout = parseCollector;
            
            parseCollector.streamFinished.connect(function() {
                callback(parseCollector.text.trim());
                parseProc.destroy();
            });
            
            parseProc.running = true;
            parseProc.write(html);
            parseProc.stdinEnabled = false; // This closes stdin
            
            proc.destroy();
        });
        proc.running = true;
    }

    function finalizeSearch(index, query, fetched, others) {
        var toolResultText = "Search results for: " + query + "\n\n";
        
        fetched.forEach((f, i) => {
            toolResultText += "Source [" + (i+1) + "]: " + f.title + " (" + f.url + ")\n";
            toolResultText += "Content excerpt: " + f.content.substring(0, 1000) + "...\n\n";
        });
        
        if (others.length > 0) {
            toolResultText += "Other relevant links:\n";
            others.forEach(o => {
                toolResultText += "- " + o.title + ": " + o.url + "\n";
            });
        }

        chatModel.setProperty(index, "toolOutput", truncateOutput(toolResultText));
        chatModel.setProperty(index, "toolStatus", "done");

        if (settings.summarizeSearch && fetched.length > 0) {
            summarizeSearch(index, query, fetched, toolResultText);
        } else {
            finishToolCall(index, toolResultText);
        }
    }

    function summarizeSearch(index, query, fetched, rawResults) {
        chatModel.setProperty(index, "toolStatus", "summarizing...");
        
        var prompt = "The user searched for: " + query + "\n\nHere are the contents of the first 3 results:\n\n";
        fetched.forEach((f, i) => {
            prompt += "Source [" + (i+1) + "]: " + f.title + "\nURL: " + f.url + "\nContent:\n" + f.content + "\n\n---\n\n";
        });
        prompt += "Please extract the most relevant excerpts and information from these results that answer the search query. Be concise but thorough.";

        var messages = [
            { role: "system", content: "You are a research assistant. Extract relevant information from provided search results." },
            { role: "user", content: prompt }
        ];

        var handler = function(content) {
            backgroundApiClient.responseReceived.disconnect(handler);
            chatModel.setProperty(index, "toolStatus", "summarized");
            var finalResult = "### Search Summary for: " + query + "\n\n" + content + "\n\n### Raw Sources\n" + rawResults.split("Other relevant links:")[0];
            if (rawResults.includes("Other relevant links:")) {
                finalResult += "\n### Other Links\n" + rawResults.split("Other relevant links:")[1];
            }
            finishToolCall(index, finalResult);
        };
        
        backgroundApiClient.responseReceived.connect(handler);
        
        backgroundApiClient.sendMessage(
            settings.apiEndpoint,
            settings.apiKey,
            config.modelName,
            messages,
            false,
            0.3
        );
    }

    function executeGetPage(index, url, prompt) {
        chatModel.setProperty(index, "toolName", "getpage");
        chatModel.setProperty(index, "toolInput", "\"" + url + "\", \"" + prompt + "\"");
        chatModel.setProperty(index, "toolStatus", "fetching page...");
        
        fetchUrl(url, function(content) {
            chatModel.setProperty(index, "toolStatus", "extracting information...");
            
            var messages = [
                { role: "system", content: "You are an assistant that extracts specific information from a webpage." },
                { role: "user", content: "Page Content:\n" + content + "\n\nTask: " + prompt }
            ];
            
            var handler = function(resContent) {
                backgroundApiClient.responseReceived.disconnect(handler);
                chatModel.setProperty(index, "toolStatus", "done");
                chatModel.setProperty(index, "toolOutput", truncateOutput(resContent));
                finishToolCall(index, "Information extracted from " + url + " using prompt \"" + prompt + "\":\n\n" + resContent);
            };
            
            backgroundApiClient.responseReceived.connect(handler);
            
            backgroundApiClient.sendMessage(
                settings.apiEndpoint,
                settings.apiKey,
                config.modelName,
                messages,
                false,
                0.3
            );
        });
    }

    function finishToolCall(index, resultText) {
        root.isLoading = true;
        
        root.messageHistory = [...root.messageHistory, { role: "user", content: "TOOL RESULT:\n\n" + resultText }];
        
        var cleanedHistory = stripReasoningFromHistory(root.messageHistory);
        apiClient.sendMessage(
            settings.apiEndpoint,
            settings.apiKey,
            config.modelName,
            cleanedHistory,
            config.enableStreaming,
            config.temperature
        );
    }

    Settings {
        id: settings
        // Using a direct file location to avoid organizationName requirements
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
            saveCurrentSession();
        }
    }

    function generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substring(2);
    }
    
    function saveCurrentSession() {
        if (currentSessionId === "") return;

        var sessions = JSON.parse(settings.savedSessions);
        var found = false;
        var title = "New Chat";

        // Find title from first user message
        for (var i = 0; i < messageHistory.length; i++) {
            if (messageHistory[i].role === "user") {
                var content = messageHistory[i].content;
                var text = "";
                if (typeof content === "string") text = content;
                else if (Array.isArray(content)) {
                    var textItem = content.find(item => item.type === "text");
                    if (textItem) text = textItem.text;
                }
                if (text) {
                    title = text.substring(0, 30) + (text.length > 30 ? "..." : "");
                    break;
                }
            }
        }

        for (var j = 0; j < sessions.length; j++) {
            if (sessions[j].id === currentSessionId) {
                sessions[j].history = messageHistory;
                sessions[j].title = title;
                sessions[j].modelName = config.modelName;
                sessions[j].temperature = config.temperature;
                sessions[j].personaId = settings.currentPersonaId;
                found = true;
                break;
            }
        }

        if (!found) {
            sessions.unshift({
                id: currentSessionId,
                title: title,
                history: messageHistory,
                modelName: config.modelName,
                temperature: config.temperature,
                personaId: settings.currentPersonaId
            });
        }

        settings.savedSessions = JSON.stringify(sessions);
        updateSessionsModel();
    }
    
    function loadSession(id) {
        var sessions = JSON.parse(settings.savedSessions);
        var session = sessions.find(s => s.id === id);
        if (session) {
            currentSessionId = id;
            settings.lastSessionId = id;
            root.messageHistory = session.history;

            // Restore model name, temperature, and persona if saved with session
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

            // Populate chatModel from history
            chatModel.clear();
            session.history.forEach(msg => {
                if (msg.role !== "system") {
                    var displayContent = "";
                    if (typeof msg.content === "string") {
                        displayContent = msg.content;
                    } else if (Array.isArray(msg.content)) {
                        msg.content.forEach(item => {
                            if (item.type === "text") displayContent += item.text;
                            else if (item.type === "image_url") displayContent += "\n[Image Attachment]";
                        });
                    }

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
        currentSessionId = generateId();
        settings.lastSessionId = currentSessionId;
        var systemContent = resolveSystemPrompt(currentPersona.system) + (currentPersona.personality ? "\n\n" + currentPersona.personality : "");
        root.messageHistory = [{ role: "system", content: systemContent }];
        chatModel.clear();
        saveCurrentSession();
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

        // Migrate default persona if necessary
        try {
            var ps = JSON.parse(settings.personas);
            var defP = ps.find(p => p.id === "default");
            var toolInfo = "\n\n# Tool Use\nYou can call tools by outputting tool[\\\"(tool_name)\\\", \\\"input1\\\", \\\"input2\\\"].\\nThe tool call MUST be at the end of your response.\\n\\nAvailable tools:\\n- tool[\\\"search\\\", \\\"query\\\"]: Searches the web using SearXNG. Returns top results and text from the first 3.\\n- tool[\\\"getpage\\\", \\\"url\\\", \\\"prompt\\\"]: Fetches a URL and uses a separate model to extract info based on the prompt.";
            
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
        saveCurrentSession();
    }
    
    onOpenedChanged: {
        if (opened) {
            root.visible = true;
            inputField.forceActiveFocus();
        } else {
            root.visible = false;
        }
    }
    
    function formatMessage(text) {
        if (!text) return "";
        
        // Escape HTML
        var formatted = text.replace(/&/g, "&")
                            .replace(/</g, "<")
                            .replace(/>/g, ">");
        
        // Code blocks
        formatted = formatted.replace(/```([\s\S]*?)```/g, function(match, code) {
            return '<pre style="padding: 5px; border: 1px solid #404040;">' + code.trim() + '</pre>';
        });
        
        // Inline code
        formatted = formatted.replace(/`([^`]+)`/g, '<code style="padding: 2px; border: 1px solid #404040;">$1</code>');
        
        // Bold
        formatted = formatted.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
        
        // Italic
        formatted = formatted.replace(/\*([^*]+)\*/g, "<i>$1</i>");

        // Strikethrough
        formatted = formatted.replace(/~~([^~]+)~~/g, "<s>$1</s>");
        
        // Headings
        formatted = formatted.replace(/^### (.*$)/gm, "<h3>$1</h3>");
        formatted = formatted.replace(/^## (.*$)/gm, "<h2>$1</h2>");
        formatted = formatted.replace(/^# (.*$)/gm, "<h1>$1</h1>");
        
        // Horizontal rules
        formatted = formatted.replace(/^---$/gm, "<hr/>");
        formatted = formatted.replace(/^\*\*\*$/gm, "<hr/>");

        // Simple table support
        formatted = formatted.replace(/^\|(.+)\|$/gm, function(match, content) {
            var cells = content.split('|').map(function(c) { return '<td style="border: 1px solid #404040; padding: 5px;">' + c.trim() + "</td>"; }).join('');
            return "<tr>" + cells + "</tr>";
        });
        formatted = formatted.replace(/((?:<tr>.*<\/tr>\n?)+)/g, '<table style="border-collapse: collapse; margin: 10px 0;">$1</table>');
        // Remove header separator row
        formatted = formatted.replace(/<tr>(?:\s*<td>\s*[:\-]+\s*<\/td>\s*)+<\/tr>/g, "");

        // Bullet points
        formatted = formatted.replace(/^[\*-] (.*$)/gm, "<li>$1</li>");
        formatted = formatted.replace(/((?:<li>.*<\/li>\n?)+)/g, "<ul>$1</ul>");
        
        // Newlines
        formatted = formatted.replace(/\n/g, "<br/>");
        // Remove <br/> after block tags that already cause a break
        formatted = formatted.replace(/(<\/(?:h1|h2|h3|ul|li|table|tr|pre|hr)>)<br\/>/g, "$1");
        
        return formatted;
    }
    
    function stripReasoningFromHistory(history) {
        var cleaned = [];
        for (var i = 0; i < history.length; i++) {
            var msg = history[i];
            if (msg.role === "assistant") {
                cleaned.push({ role: "assistant", content: msg.content });
            } else {
                cleaned.push(msg);
            }
        }
        return cleaned;
    }

    function contentToString(content) {
        if (typeof content === "string") return content;
        if (Array.isArray(content)) {
            var result = "";
            content.forEach(item => {
                if (item.type === "text") result += item.text;
                else if (item.type === "image_url") result += "\n[Image Attachment]";
                else if (item.type === "input_audio") result += "\n[Audio Attachment]";
            });
            return result;
        }
        return String(content);
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
                // Treat as text document
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
    
    // Message history for API
    property var messageHistory: [
        { role: "system", content: "You are a helpful assistant." }
    ]
    
    FileDialog {
        id: fileDialog
        title: "Select attachments"
        currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            var newAttachments = [...root.attachments];
            for (var i = 0; i < selectedFiles.length; i++) {
                var url = selectedFiles[i].toString();
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
    
    Item {
        id: sideMenu
        width: 300
        height: root.height
        z: 100
        
        property bool isOpen: false

        function open() { isOpen = true; }
        function close() { isOpen = false; }
        
        // Background overlay for the rest of the panel to close on click
        MouseArea {
            x: 0
            y: 0
            width: root.width
            height: root.height
            visible: sideMenu.isOpen
            onClicked: sideMenu.close()
        }
        
        Rectangle {
            width: 300
            height: parent.height
            color: "#1A1A1A"
            border.color: "#404040"
            border.width: 1
            
            x: sideMenu.isOpen ? 0 : -width
            Behavior on x {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            
            // Catch clicks on the menu itself
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15
                
                Text {
                    text: "Chat History"
                    color: "#c5c5c5"
                    font.family: "Monospace"
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignHCenter
                }
                
                ListView {
                    id: sessionsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ListModel { id: sessionsModel }
                    spacing: 5
                    delegate: ItemDelegate {
                        width: sessionsListView.width
                        height: 50
                        padding: 10
                        contentItem: RowLayout {
                            Text {
                                text: title
                                color: currentSessionId === id ? "#FFFFFF" : "#c5c5c5"
                                font.family: "Monospace"
                                font.pixelSize: 14
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            
                            Item {
                                width: 20
                                height: 20
                                Text {
                                    text: "×"
                                    color: "#808080"
                                    font.pixelSize: 20
                                    visible: hovered
                                    anchors.centerIn: parent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var sessions = JSON.parse(settings.savedSessions);
                                        var index = sessions.findIndex(s => s.id === id);
                                        if (index !== -1) {
                                            sessions.splice(index, 1);
                                            settings.savedSessions = JSON.stringify(sessions);
                                            updateSessionsModel();
                                            if (currentSessionId === id) {
                                                if (sessions.length > 0) loadSession(sessions[0].id);
                                                else createNewSession();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        background: Rectangle {
                            color: hovered ? "#333333" : (currentSessionId === id ? "#222222" : "transparent")
                            border.color: currentSessionId === id ? "#404040" : "transparent"
                        }
                        onClicked: {
                            loadSession(id);
                            sideMenu.close();
                        }
                    }
                }
                
                Button {
                    text: "New Chat"
                    Layout.fillWidth: true
                    onClicked: {
                        createNewSession();
                        sideMenu.close();
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#333333" : "#1A1A1A"
                        border.color: "#404040"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#c5c5c5"
                        font.family: "Monospace"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
    
    Popup {
        id: settingsPopup
        x: 0
        y: 0
        width: parent.width
        height: parent.height
        modal: true
        focus: true
        padding: 20

        onOpened: {
            personasModel.clear();
            var ps = JSON.parse(settings.personas);
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
                            TextField {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 250
                                text: settings.apiEndpoint
                                placeholderText: "http://..."
                                placeholderTextColor: "#808080"
                                color: "#c5c5c5"
                                font.family: "Monospace"
                                background: Rectangle { color: "#222222"; border.color: "#404040" }
                                onTextChanged: {
                                    settings.apiEndpoint = text;
                                    config.apiEndpoint = text;
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text { text: "API Key"; color: "#c5c5c5"; font.family: "Monospace"; font.pixelSize: 12 }
                            RowLayout {
                                Layout.fillWidth: true
                                TextField {
                                    id: apiKeyField
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 200
                                    text: settings.apiKey
                                    echoMode: showApiKey.checked ? TextInput.Normal : TextInput.Password
                                    color: "#c5c5c5"
                                    placeholderTextColor: "#808080"
                                    font.family: "Monospace"
                                    background: Rectangle { color: "#222222"; border.color: "#404040" }
                                    onTextChanged: {
                                        settings.apiKey = text;
                                        config.apiKey = text;
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
                            TextField {
                                Layout.fillWidth: true
                                text: settings.searxngUrl
                                placeholderText: "http://localhost:8080"
                                color: "#c5c5c5"
                                font.family: "Monospace"
                                background: Rectangle { color: "#222222"; border.color: "#404040" }
                                onTextChanged: {
                                    settings.searxngUrl = text;
                                    config.searxngUrl = text;
                                }
                            }
                        }

                        CheckBox {
                            text: "Summarize Search Results"
                            checked: settings.summarizeSearch
                            background: Rectangle { color: "#222222"; border.color: "#404040" }
                            contentItem: Text { text: "Summarize Search Results"; color: "#c5c5c5"; font.family: "Monospace"; leftPadding: 25 }
                            onCheckedChanged: {
                                settings.summarizeSearch = checked;
                                config.summarizeSearch = checked;
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: "Temperature: " + settings.temperature.toFixed(1)
                                color: "#c5c5c5"
                                font.family: "Monospace"
                                font.pixelSize: 12
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                height: 20
                                Item { width: 5 }                                 Rectangle {
                                    id: temperatureSliderTrackContainer
                                    Layout.fillWidth: true
                                    height: 6
                                    color: "#222222"
                                    radius: 3
                                    Rectangle {
                                        id: temperatureTrack
                                        width: (settings.temperature / 2.0) * parent.width
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
                                            settings.temperature = Math.max(0, Math.min(2.0, newVal));
                                            config.temperature = settings.temperature;
                                        }
                                        onPositionChanged: {
                                            if (mouse.buttons === Qt.LeftButton) {
                                                var ratio = mouse.x / width;
                                                var newVal = ratio * 2.0;
                                                newVal = Math.round(newVal * 10) / 10;
                                                settings.temperature = Math.max(0, Math.min(2.0, newVal));
                                                config.temperature = settings.temperature;
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
                                color: settings.currentPersonaId === id ? "#222222" : "transparent"
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
                                        Button {
                                            text: "Select"
                                            visible: settings.currentPersonaId !== id
                                            background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                                            contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                                            onClicked: settings.currentPersonaId = id
                                        }
                                        Button {
                                            text: "Edit"
                                            background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                                            contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                                            onClicked: {
                                                editPersonaPopup.editingId = id;
                                                editPersonaName.text = name;
                                                editPersonaSystem.text = system;
                                                editPersonaPersonality.text = personality || "";
                                                editPersonaPopup.open();
                                            }
                                        }
                                        Button {
                                            text: "Delete"
                                            visible: id !== "default"
                                            background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                                            contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                                            onClicked: {
                                                var ps = JSON.parse(settings.personas);
                                                var idx = ps.findIndex(p => p.id === id);
                                                if (idx !== -1) {
                                                    ps.splice(idx, 1);
                                                    settings.personas = JSON.stringify(ps);
                                                    if (settings.currentPersonaId === id) settings.currentPersonaId = "default";

                                                    personasModel.clear();
                                                    ps.forEach(p => personasModel.append(p));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            text: "+ Add Persona"
                            Layout.fillWidth: true
                            background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                            contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                            onClicked: {
                                newPersonaSystem.text = "You are a helpful assistant. System Info:\\n- OS: {os}\\n- Kernel: {kernel}\\n- DE: {de}\\n- User: {user}\\n- Host: {hostname}\\n- Time: {date time}\\n\\n# Tool Use\\nYou can call tools by outputting tool[\\\"(tool_name)\\\", \\\"input1\\\", \\\"input2\\\"].\\nThe tool call MUST be at the end of your response.\\n\\nAvailable tools:\\n- tool[\\\"search\\\", \\\"query\\\"]: Searches the web using SearXNG. Returns top results and text from the first 3.\\n- tool[\\\"getpage\\\", \\\"url\\\", \\\"prompt\\\"]: Fetches a URL and uses a separate model to extract info based on the prompt.";
                                addPersonaPopup.open();
                            }
                        }
                    }
                }
            }

            Button {
                text: "Close"
                Layout.alignment: Qt.AlignRight
                background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                onClicked: settingsPopup.close()
            }
        }
    }

    Popup {
        id: addPersonaPopup
        anchors.centerIn: parent
        width: 400
        height: 500
        modal: true
        focus: true
        padding: 20
        background: Rectangle { color: "#1A1A1A"; border.color: "#404040" }

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

                TextField {
                    id: newPersonaName
                    Layout.fillWidth: true
                    placeholderText: "Name"
                    color: "#c5c5c5"
                    placeholderTextColor: "#808080"
                    font.family: "Monospace"
                    background: Rectangle { color: "#222222"; border.color: "#404040" }
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
                    Button {
                        text: "Cancel"
                        background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                        contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                        onClicked: addPersonaPopup.close()
                    }
                    Button {
                        text: "Save"
                        background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                        contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                        onClicked: {
                            if (newPersonaName.text !== "") {
                                var ps = JSON.parse(settings.personas);
                                var newP = {
                                    id: generateId(),
                                    name: newPersonaName.text,
                                    system: newPersonaSystem.text,
                                    personality: newPersonaPersonality.text
                                };
                                ps.push(newP);
                                settings.personas = JSON.stringify(ps);

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

    Popup {
        id: editPersonaPopup
        anchors.centerIn: parent
        width: 400
        height: 500
        modal: true
        focus: true
        padding: 20
        background: Rectangle { color: "#1A1A1A"; border.color: "#404040" }

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

                TextField {
                    id: editPersonaName
                    Layout.fillWidth: true
                    placeholderText: "Name"
                    color: "#c5c5c5"
                    placeholderTextColor: "#808080"
                    font.family: "Monospace"
                    background: Rectangle { color: "#222222"; border.color: "#404040" }
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
                    Button {
                        text: "Cancel"
                        background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                        contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                        onClicked: editPersonaPopup.close()
                    }
                    Button {
                        text: "Save"
                        background: Rectangle { color: parent.hovered ? "#333333" : "#222222"; border.color: "#404040" }
                        contentItem: Text { text: parent.text; color: "#c5c5c5"; font.family: "Monospace"; horizontalAlignment: Text.AlignHCenter }
                        onClicked: {
                            if (editPersonaName.text !== "") {
                                var ps = JSON.parse(settings.personas);
                                var idx = ps.findIndex(p => p.id === editPersonaPopup.editingId);
                                if (idx !== -1) {
                                    ps[idx].name = editPersonaName.text;
                                    ps[idx].system = editPersonaSystem.text;
                                    ps[idx].personality = editPersonaPersonality.text;
                                    settings.personas = JSON.stringify(ps);

                                    // Refresh currentPersona if it was the one edited
                                    if (settings.currentPersonaId === editPersonaPopup.editingId) {
                                        var temp = settings.currentPersonaId;
                                        settings.currentPersonaId = "";
                                        settings.currentPersonaId = temp;
                                    }

                                    // Refresh model
                                    personasModel.clear();
                                    ps.forEach(p => personasModel.append(p));

                                    editPersonaPopup.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Main container with animation
    Rectangle {
        id: container
        width: parent.width
        height: parent.height
        color: "black"
        
        // Slide animation logic
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
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                height: 40

                 Rectangle {
                    width: 40
                    height: 28
                    color: menuMouseArea.containsMouse ? "#333333" : "transparent"
                    Image {
                        source: "menu.svg"
                        sourceSize: Qt.size(37, 24)
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        id: menuMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: {
                            if (sideMenu.isOpen) {
                                sideMenu.close();
                            } else {
                                sideMenu.open();
                            }
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    color: plusMouseArea.containsMouse ? "#333333" : "transparent"
                    Image {
                        source: "plus.svg"
                        sourceSize: Qt.size(20, 20)
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        id: plusMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: {
                            createNewSession();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: currentPersona.name
                    color: "#808080"
                    font.family: "Monospace"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    width: 28
                    height: 28
                    color: settingsMouseArea.containsMouse ? "#333333" : "transparent"
                    Image {
                        source: "cog.svg"
                        sourceSize: Qt.size(24, 24)
                        anchors.centerIn: parent
                        fillMode: Image.Pad
                    }
                    MouseArea {
                        id: settingsMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: settingsPopup.open()
                    }
                }
            }
            
            // Chat area
            ListView {
                id: chatView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 20
                cacheBuffer: 2000
                
                model: ListModel {
                    id: chatModel
                }
                
                delegate: ColumnLayout {
                    width: chatView.width
                    height: implicitHeight
                    spacing: 0
                    
                    RetroFrame {
                        id: msgFrame
                        Layout.fillWidth: true
                        title: sender === "You" ? "user" : "ai"
                        borderColor: sender === "You" ? "#c5c5c5" : "#c5c5c5"
                        
                        rightElement: Item {
                            implicitWidth: sender === "You" ? 16 : (modelNameText.implicitWidth + 20)
                            implicitHeight: sender === "You" ? 16 : 16
                            width: implicitWidth
                            height: implicitHeight
                            Image {
                                visible: sender === "You"
                                source: "pencil.svg"
                                sourceSize: Qt.size(16, 16)
                                anchors.centerIn: parent
                            }
                            Text {
                                id: modelNameText
                                visible: sender !== "You"
                                text: config.modelName
                                color: "#c5c5c5"
                                font.family: "Monospace"
                                font.pixelSize: 12
                                anchors.centerIn: parent
                            }
                        }
                        titlePadding: sender === "You" ? 2 : 10
                        
                        ColumnLayout {
                            width: parent.width
                            height: implicitHeight
                            spacing: 15
                            
                            // Thought box for AI
                            RetroFrame {
                                id: thoughtFrame
                                Layout.fillWidth: true
                                visible: sender === "AI" && (thinking !== "" || root.isLoading && message === "")
                                title: "thought"
                                borderColor: "#808080"
                                property bool collapsed: false
                                stickyScroll: chatView
                                
                                rightElement: Image {
                                    source: "dropdown.svg"
                                    sourceSize: Qt.size(14, 16)
                                    width: 14
                                    height: 16
                                    rotation: thoughtFrame.collapsed ? -90 : 0
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: thoughtFrame.collapsed = !thoughtFrame.collapsed
                                    }
                                }
                                
                                TextEdit {
                                    width: parent.width
                                    visible: !thoughtFrame.collapsed
                                    height: visible ? implicitHeight : 0
                                    text: formatMessage(thinking)
                                    textFormat: Text.RichText
                                    color: "#808080"
                                    font.family: "Monospace"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    selectByMouse: true
                                    readOnly: true
                                }
                            }
                            
                            // Tool box for AI
                            RetroFrame {
                                id: toolFrame
                                Layout.fillWidth: true
                                visible: (toolName || "") !== ""
                                title: "tool"
                                borderColor: "#4A90E2"
                                property bool collapsed: false
                                stickyScroll: chatView
                                
                                rightElement: Image {
                                    source: "dropdown.svg"
                                    sourceSize: Qt.size(14, 16)
                                    width: 14
                                    height: 16
                                    rotation: toolFrame.collapsed ? -90 : 0
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: toolFrame.collapsed = !toolFrame.collapsed
                                    }
                                }
                                
                                ColumnLayout {
                                    width: parent.width
                                    visible: !toolFrame.collapsed
                                    spacing: 5
                                    
                                    Text {
                                        text: "<b>Call:</b> " + toolName + "[" + toolInput + "]"
                                        color: "#c5c5c5"
                                        font.family: "Monospace"
                                        font.pixelSize: 12
                                        textFormat: Text.RichText
                                    }
                                    
                                    Text {
                                        text: "<b>Status:</b> " + toolStatus
                                        color: "#808080"
                                        font.family: "Monospace"
                                        font.pixelSize: 10
                                        textFormat: Text.RichText
                                    }

                                    TextEdit {
                                        Layout.fillWidth: true
                                        text: toolOutput
                                        color: "#808080"
                                        font.family: "Monospace"
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        selectByMouse: true
                                        readOnly: true
                                        visible: toolOutput !== ""
                                    }
                                }
                            }
                            
                            TextEdit {
                                Layout.fillWidth: true
                                text: sender === "AI" ? formatMessage(message) : message
                                textFormat: sender === "AI" ? Text.RichText : Text.PlainText
                                color: "#c5c5c5"
                                font.family: "Monospace"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                visible: message !== ""
                                selectByMouse: true
                                readOnly: true
                            }
                        }
                    }
                }
            }
                
            // Input area
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                
                // Attachments preview
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.attachments.length > 0
                    spacing: 10
                                        Repeater {
                        model: root.attachments
                        RetroFrame {
                            id: frameItem
                            implicitWidth: 60; implicitHeight: 60
                            title: "file"
                            borderColor: "#808080"
                            
                            Item {
                                width: 36
                                height: 36
                                
                                Image {
                                    anchors.fill: parent
                                    source: modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i) ? "file://" + modelData : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i)
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "FILE"
                                    color: "#808080"
                                    font.family: "Monospace"
                                    font.pixelSize: 8
                                    visible: !modelData.match(/\.(jpg|jpeg|png|gif|webp)$/i)
                                }
                                
                                Rectangle {
                                    id: deleteAttachmentBtn
                                    width: 14
                                    height: 14
                                    color: "#1A1A1A"
                                    border.color: deleteMouseArea.containsMouse ? "#FFFFFF" : "#808080"
                                    border.width: 1
                                    parent: frameItem
                                    anchors.top: frameItem.top
                                    anchors.right: frameItem.right
                                    anchors.topMargin: 2
                                    anchors.rightMargin: 2
                                    z: 10
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: deleteMouseArea.containsMouse ? "#FFFFFF" : "#808080"
                                        font.pixelSize: 10
                                        font.bold: true
                                        anchors.verticalCenterOffset: -1
                                    }
                                    
                                    MouseArea {
                                        id: deleteMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            var newAttachments = [...root.attachments];
                                            newAttachments.splice(index, 1);
                                            root.attachments = newAttachments;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.min(300, Math.max(80, inputField.implicitHeight + 20))
                    color: "#1A1A1A"
                    
                    ScrollView {
                        anchors.fill: parent
                        TextArea {
                            id: inputField
                            padding: 10
                            placeholderText: "type your message..."
                            color: "#c5c5c5"
                            placeholderTextColor: "#808080"
                            font.family: "Monospace"
                            font.pixelSize: 14
                            enabled: !root.isLoading
                            wrapMode: Text.WordWrap
                            background: null
                            
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Return && event.modifiers === Qt.ControlModifier) {
                                    sendButton.send();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    height: 30
 
                    Rectangle {
                        id: paperclipButton
                        width: 24
                        height: 24
                        color: paperclipMouseArea.containsMouse ? "#333333" : "transparent"
                        Image {
                            source: "paperclip.svg"
                            sourceSize: Qt.size(15, 30)
                            width: 15
                            height: 30
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            id: paperclipMouseArea
                            hoverEnabled: true
                            anchors.fill: parent
                            onClicked: fileDialog.open()
                        }
                    }

                    Item { width: 20 }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 5

                        Item {
                            width: 14
                            height: 16
                            Image {
                                id: modelPickerArrow
                                source: "dropdown.svg"
                                sourceSize: Qt.size(14, 16)
                                anchors.centerIn: parent
                                rotation: modelPickerPopup.opened ? 180 : 0
                            }
                            MouseArea {
                                id: modelPickerArrowMouseArea
                                hoverEnabled: true
                                anchors.fill: parent
                                onClicked: {
                                    if (modelPickerPopup.opened) {
                                        modelPickerPopup.close();
                                    } else {
                                        openModelPicker();
                                    }
                                }
                            }
                        }

                        Item {
                            width: modelPickerText.contentWidth
                            height: modelPickerText.contentHeight
                            Text {
                                id: modelPickerText
                                text: config.modelName
                                color: "#c5c5c5"
                                font.family: "Monospace"
                                font.pixelSize: 14
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                id: modelPickerTextMouseArea
                                hoverEnabled: true
                                anchors.fill: parent
                                onClicked: {
                                    if (modelPickerPopup.opened) {
                                        modelPickerPopup.close();
                                    } else {
                                        openModelPicker();
                                    }
                                }
                            }
                        }
                    }

                    Popup {
                        id: modelPickerPopup
                        y: -height - 5
                        width: 300
                        height: Math.min(400, modelsModel.count * 30 + 10)
                        padding: 5
                        closePolicy: Popup.CloseOnEscape

                        background: Rectangle {
                            color: "#1A1A1A"
                            border.color: "#404040"
                        }

                        contentItem: ListView {
                            id: modelsListView
                            model: ListModel { id: modelsModel }
                            delegate: ItemDelegate {
                                width: modelsListView.width
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

                    Item { Layout.fillWidth: true }

                    // Custom Send Button
                    Rectangle {
                        id: sendButton
                        width: 30
                        height: 30
                        color: "transparent"

                        function send() {
                            if (!root.isLoading && (inputField.text.trim() !== "" || root.attachments.length > 0)) {
                                var text = inputField.text.trim();
                                var displayMessage = text;

                                chatModel.append({
                                   sender: "You",
                                   message: displayMessage,
                                   thinking: "",
                                   toolName: "",
                                   toolInput: "",
                                   toolOutput: "",
                                   toolStatus: ""
                                });

                                // Prepare for API
                                var currentText = text;
                                var currentAttachments = [...root.attachments];
                                
                                // Reset UI
                                inputField.text = "";
                                root.attachments = [];
                                chatView.positionViewAtEnd();
                                
                                root.isLoading = true;
                                
                                processAttachments(currentAttachments, function(attachmentContents) {
                                    var content = [];
                                    if (currentText !== "") {
                                        content.push({ type: "text", text: currentText });
                                    }
                                    attachmentContents.forEach(item => content.push(item));
                                    
                                    var finalContent = content.length === 1 && content[0].type === "text" ? currentText : content;

                                    root.messageHistory = [...root.messageHistory, { role: "user", content: finalContent }];
                                    
                                    var cleanedHistory = stripReasoningFromHistory(root.messageHistory);
                                    
                                    apiClient.sendMessage(
                                        settings.apiEndpoint,
                                        settings.apiKey,
                                        config.modelName,
                                        cleanedHistory,
                                        config.enableStreaming,
                                        config.temperature
                                    );
                                });
                            } else if (root.isLoading) {
                                apiClient.stop();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.isLoading ? "■" : "→|"
                            color: root.isLoading || inputField.text.trim() !== "" || root.attachments.length > 0 ? "#c5c5c5" : "#404040"
                            font.family: "Monospace"
                            font.pixelSize: root.isLoading ? 24 : 20
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: sendButton.send()
                        }
                    }
                }
            }
        }
    }
}

