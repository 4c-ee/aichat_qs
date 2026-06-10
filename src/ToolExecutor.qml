import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var chatModel
    property var settings
    property var config
    property var backgroundApiClient

    signal toolCallFinished(int index, string resultText)

    function truncateOutput(text, limit) {
        if (!text) return "";
        var l = limit || 500;
        if (text.length <= l) return text;
        return text.substring(0, l) + "... [truncated]";
    }

    function checkForToolCall(index, content) {
        if (!content) return;

        var trimmed = content.trim();
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
            parseProc.stdinEnabled = false;

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
        toolCallFinished(index, resultText);
    }
}