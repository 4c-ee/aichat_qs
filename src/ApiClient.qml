import QtQuick
import Quickshell
import Quickshell.Io

Item {
    // All communication now handled via XMLHttpRequest in sendMessage and getModels

    id: root

    property string pendingData: ""
    property bool isStreaming: false
    property bool streamAborted: false
    property int lastLineProcessed: 0
    property string requestId: ""
    property var activeXhr: null
    property int lastExitCode: 0

    signal responseReceived(string content, string reasoning)
    signal responseChunk(string content)
    signal thinkingChunk(string content)
    signal streamingFinished()
    signal errorOccurred(string error)
    signal modelsReceived(var models)

    function getModels(endpoint, apiKey) {
        var trimmedEndpoint = endpoint.trim();
        if (trimmedEndpoint.endsWith("/"))
            trimmedEndpoint = trimmedEndpoint.substring(0, trimmedEndpoint.length - 1);

        if (trimmedEndpoint.includes("googleapis.com") && trimmedEndpoint.startsWith("http://"))
            trimmedEndpoint = "https://" + trimmedEndpoint.substring(7);

        var url = trimmedEndpoint + "/models";
        var trimmedKey = apiKey ? apiKey.trim() : "";
        console.log("Fetching models from:", url);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        if (trimmedKey !== "")
            xhr.setRequestHeader("Authorization", "Bearer " + trimmedKey);

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var modelIds = [];
                        if (response.data)
                            modelIds = response.data.map((m) => {
                            return m.id;
                        });
                        else if (Array.isArray(response))
                            modelIds = response.map((m) => {
                            return m.id || m.name || m;
                        });
                        else if (response.models)
                            modelIds = response.models.map((m) => {
                            return m.name || m.id || m;
                        });
                        root.modelsReceived(modelIds);
                    } catch (e) {
                        console.error("Failed to parse models:", e);
                    }
                } else {
                    console.error("Models request failed with status:", xhr.status, xhr.responseText);
                }
            }
        };
        xhr.send();
    }

    function sendMessage(endpoint, apiKey, model, messages, stream = false, temperature = null) {
        if (root.activeXhr) {
            root.activeXhr.abort();
            root.activeXhr = null;
        }
        streamAborted = false;
        isStreaming = stream;
        lastLineProcessed = 0;
        var trimmedEndpoint = endpoint.trim();
        if (trimmedEndpoint.endsWith("/"))
            trimmedEndpoint = trimmedEndpoint.substring(0, trimmedEndpoint.length - 1);

        var isGoogle = trimmedEndpoint.includes("googleapis.com");
        if (isGoogle && trimmedEndpoint.startsWith("http://"))
            trimmedEndpoint = "https://" + trimmedEndpoint.substring(7);

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
            root.activeXhr = null;
            root.errorOccurred("Network Error: Connection failed.");
        };
        xhr.send(jsonBody);
    }

    function stop() {
        if (root.activeXhr) {
            root.activeXhr.abort();
            root.activeXhr = null;
            streamAborted = true;
            isStreaming = false;
            root.errorOccurred("Request stopped by user.");
        }
    }

}
