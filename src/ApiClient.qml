import QtQuick
import Quickshell
import Quickshell.Io

Item {
    // All communication now handled via XMLHttpRequest in sendMessage and getModels

    id: root

    property string pendingData: ""
    property bool isStreaming: false
    property int lastLineProcessed: 0
    property string requestId: ""
    property var activeXhr: null
    property var activeModelsXhr: null
    property int modelsRequestId: 0
    property bool modelsRequestTimedOut: false
    property int lastExitCode: 0

    Timer {
        id: modelsTimeoutTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (!root.activeModelsXhr)
                return;

            root.modelsRequestTimedOut = true;
            var timedOutXhr = root.activeModelsXhr;
            root.activeModelsXhr = null;
            timedOutXhr.abort();
            root.modelsFailed("Models request timed out. Check the endpoint URL and protocol.");
        }
    }

    signal responseReceived(string content, string reasoning)
    signal responseChunk(string content)
    signal thinkingChunk(string content)
    signal streamingFinished()
    signal requestStopped()
    signal errorOccurred(string error)
    signal modelsReceived(var models)
    signal modelsFailed(string error)

    function extractModelIds(response) {
        var entries = [];

        function appendEntries(value) {
            if (Array.isArray(value))
                entries = entries.concat(value);
            else if (value && typeof value === "object")
                entries.push(value);
        }

        if (Array.isArray(response)) {
            appendEntries(response);
        } else if (response) {
            // OpenAI-compatible endpoints use "data", while llama-server and
            // Ollama-style endpoints use "models". Some servers return both.
            appendEntries(response.data);
            appendEntries(response.models);
        }

        var modelIds = [];
        entries.forEach(function(entry) {
            var modelId;
            if (typeof entry === "string") {
                modelId = entry;
            } else if (entry && typeof entry === "object") {
                modelId = entry.id || entry.name || entry.model;
                if (modelId && typeof modelId === "object")
                    modelId = modelId.id || modelId.name || modelId.model;
            }

            if (modelId === undefined || modelId === null)
                return;

            modelId = String(modelId).trim();
            if (modelId !== "" && modelIds.indexOf(modelId) === -1)
                modelIds.push(modelId);
        });

        return modelIds;
    }

    function normalizeEndpoint(endpoint) {
        var trimmedEndpoint = (endpoint || "").trim();
        if (trimmedEndpoint.endsWith("/"))
            trimmedEndpoint = trimmedEndpoint.substring(0, trimmedEndpoint.length - 1);

        if (!/^https?:\/\//i.test(trimmedEndpoint)) {
            var isLocal = /^(localhost|127(?:\.\d{1,3}){3}|\[::1\])(?::|\/|$)/i.test(trimmedEndpoint);
            trimmedEndpoint = (isLocal ? "http://" : "https://") + trimmedEndpoint;
        }

        if (trimmedEndpoint.includes("googleapis.com") && trimmedEndpoint.startsWith("http://"))
            trimmedEndpoint = "https://" + trimmedEndpoint.substring(7);

        return trimmedEndpoint;
    }

    function modelUrls(endpoint) {
        var trimmedEndpoint = root.normalizeEndpoint(endpoint);
        var urls = [];
        if (trimmedEndpoint.endsWith("/models")) {
            urls.push(trimmedEndpoint);
            return urls;
        }

        urls.push(trimmedEndpoint + "/models");

        // llama-server exposes its native model list at /models, while some
        // OpenAI-compatible configurations point at /v1. Try the native path
        // as a fallback when the OpenAI-style path is not available.
        if (trimmedEndpoint.endsWith("/v1")) {
            var baseEndpoint = trimmedEndpoint.substring(0, trimmedEndpoint.length - 3).replace(/\/+$/, "");
            if (baseEndpoint !== "")
                urls.push(baseEndpoint + "/models");
        }

        return urls;
    }

    function getModels(endpoint, apiKey) {
        root.modelsRequestId += 1;
        var requestId = root.modelsRequestId;
        root.modelsRequestTimedOut = false;
        modelsTimeoutTimer.stop();
        if (!endpoint || endpoint.trim() === "") {
            root.modelsFailed("API endpoint is empty.");
            return;
        }
        if (root.activeModelsXhr) {
            root.activeModelsXhr.abort();
            root.activeModelsXhr = null;
        }

        var urls = root.modelUrls(endpoint);
        var urlIndex = 0;
        var trimmedKey = apiKey ? apiKey.trim() : "";

        function requestNext() {
            if (requestId !== root.modelsRequestId)
                return;

            if (urlIndex >= urls.length) {
                root.modelsFailed("No models endpoint was found.");
                return;
            }

            var url = urls[urlIndex++];
            console.log("Fetching models from:", url);
            var xhr = new XMLHttpRequest();
            root.activeModelsXhr = xhr;
            var requestFinished = false;

            xhr.open("GET", url, true);
            xhr.setRequestHeader("Content-Type", "application/json");
            if (trimmedKey !== "")
                xhr.setRequestHeader("Authorization", "Bearer " + trimmedKey);

            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE || requestFinished)
                    return;

                requestFinished = true;
                if (requestId !== root.modelsRequestId)
                    return;

                root.activeModelsXhr = null;
                modelsTimeoutTimer.stop();
                if (root.modelsRequestTimedOut)
                    return;

                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        root.modelsReceived(root.extractModelIds(response));
                    } catch (e) {
                        console.error("Failed to parse models:", e);
                        root.modelsFailed("Failed to parse the models response: " + e.message);
                    }
                } else if (xhr.status === 404 && urlIndex < urls.length) {
                    requestNext();
                } else {
                    console.error("Models request failed with status:", xhr.status, xhr.responseText);
                    root.modelsFailed("Models request failed (" + xhr.status + ").");
                }
            };

            xhr.onerror = function() {
                if (requestFinished)
                    return;

                requestFinished = true;
                if (requestId !== root.modelsRequestId)
                    return;

                root.activeModelsXhr = null;
                modelsTimeoutTimer.stop();
                if (root.modelsRequestTimedOut)
                    return;

                if (urlIndex < urls.length)
                    requestNext();
                else
                    root.modelsFailed("Could not connect to the models endpoint.");
            };

            modelsTimeoutTimer.restart();
            xhr.send();
        }

        requestNext();
    }

    function sendMessage(endpoint, apiKey, model, messages, stream = false, temperature = null) {
        if (root.activeXhr) {
            root.activeXhr.userStopped = true;
            root.activeXhr.abort();
            root.activeXhr = null;
        }
        isStreaming = stream;
        lastLineProcessed = 0;
        var trimmedEndpoint = root.normalizeEndpoint(endpoint);
        var url = trimmedEndpoint + "/chat/completions";
        var trimmedKey = apiKey ? apiKey.trim() : "";
        var requestBody = {
            "model": model,
            "messages": messages
        };
        if (stream)
            requestBody.stream = true;

        if (temperature !== null && temperature !== undefined)
            requestBody.temperature = temperature;

        var jsonBody = "";
        try {
            jsonBody = JSON.stringify(requestBody);
        } catch (e) {
            root.errorOccurred("Failed to serialize request: " + e.message);
            return ;
        }
        console.log("Sending request to:", url);
        var xhr = new XMLHttpRequest();
        xhr.userStopped = false;
        root.activeXhr = xhr;
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        if (trimmedKey !== "")
            xhr.setRequestHeader("Authorization", "Bearer " + trimmedKey);

        var lastHandledIndex = 0;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 3 || xhr.readyState === 4) {
                if (xhr.status === 200) {
                    if (stream) {
                        var currentText = xhr.responseText;
                        var newText = currentText.substring(lastHandledIndex);
                        lastHandledIndex = currentText.length;
                        var lines = newText.split('\n');
                        for (var i = 0; i < lines.length; i++) {
                            var line = lines[i].trim();
                            if (line.startsWith('data:')) {
                                var data = line.substring(5).trim();
                                if (data === '' || data === '[DONE]')
                                    continue;

                                try {
                                    var chunk = JSON.parse(data);
                                    if (chunk.choices && chunk.choices.length > 0) {
                                        var delta = chunk.choices[0].delta || {
                                        };
                                        if (delta.reasoning_content)
                                            root.thinkingChunk(delta.reasoning_content);

                                        if (delta.content)
                                            root.responseChunk(delta.content);

                                    }
                                } catch (e) {
                                }
                            }
                        }
                    }
                }
            }
            if (xhr.readyState === 4) {
                root.activeXhr = null;
                if (xhr.status === 200) {
                    if (stream) {
                        root.streamingFinished();
                    } else {
                        try {
                            var response = JSON.parse(xhr.responseText);
                            if (response.choices && response.choices.length > 0) {
                                var content = response.choices[0].message.content || "";
                                var reasoning = response.choices[0].message.reasoning_content || "";
                                root.responseReceived(content, reasoning);
                            } else if (response.error) {
                                root.errorOccurred("API Error: " + response.error.message);
                            } else {
                                root.errorOccurred("Unknown API Response format");
                            }
                        } catch (e) {
                            root.errorOccurred("Failed to parse response: " + e.message);
                        }
                    }
                } else if (xhr.status !== 0) {
                    try {
                        var errRes = JSON.parse(xhr.responseText);
                        root.errorOccurred("API Error (" + xhr.status + "): " + (errRes.error ? errRes.error.message : xhr.responseText));
                    } catch (e) {
                        root.errorOccurred("Network Error (" + xhr.status + "): " + xhr.responseText);
                    }
                }
            }
        };
        xhr.onerror = function() {
            if (xhr.userStopped)
                return;

            root.activeXhr = null;
            root.errorOccurred("Network Error: Connection failed.");
        };
        xhr.send(jsonBody);
    }

    function stop() {
        if (root.activeXhr) {
            isStreaming = false;

            var xhr = root.activeXhr;
            root.activeXhr = null;
            xhr.userStopped = true;
            xhr.abort();
            root.requestStopped();
        }
    }

}
