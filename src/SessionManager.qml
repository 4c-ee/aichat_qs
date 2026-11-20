import QtQuick
import "MessageFormatter.js" as MessageFormatter

QtObject {
    id: root

    property var settings
    property string currentSessionId
    property var config
    property var resolveSystemPromptFn
    property var currentPersona
    property string _lastSavedHistory: ""

    // Cap the retained session list so the INI-backed savedSessions string
    // cannot grow without bound.
    property int maxSavedSessions: 50

    function generateId() {
        return MessageFormatter.generateId();
    }

    function saveCurrentSession(messageHistory) {
        if (currentSessionId === "") return;

        // Skip the full sessions-list rewrite when the current session's
        // history is unchanged (onMessageHistoryChanged can fire on no-op
        // ticks, and serializing every session on every message is O(total
        // history)).
        var historyStr = JSON.stringify(messageHistory);
        if (historyStr === _lastSavedHistory)
            return;
        _lastSavedHistory = historyStr;

        var sessions = JSON.parse(settings.savedSessions);
        var found = false;
        var title = "new chat";

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

        // Drop the oldest sessions once the cap is exceeded (sessions are
        // newest-first, so pop() removes the oldest).
        while (sessions.length > maxSavedSessions)
            sessions.pop();

        settings.savedSessions = JSON.stringify(sessions);
    }

    function loadSession(id) {
        var sessions = JSON.parse(settings.savedSessions);
        var session = sessions.find(s => s.id === id);
        if (session) {
            return session;
        }
        return null;
    }

    function createNewSession() {
        var newId = generateId();
        settings.lastSessionId = newId;
        var systemContent = resolveSystemPromptFn(currentPersona.system) + (currentPersona.personality ? "\n\n" + currentPersona.personality : "");
        return {
            id: newId,
            history: [{ role: "system", content: systemContent }]
        };
    }

    function deleteSession(id) {
        var sessions = JSON.parse(settings.savedSessions);
        var index = sessions.findIndex(s => s.id === id);
        if (index !== -1) {
            sessions.splice(index, 1);
            settings.savedSessions = JSON.stringify(sessions);

            // Clear dangling lastSessionId if the deleted session was the last one.
            if (settings.lastSessionId === id) {
                settings.lastSessionId = sessions.length > 0 ? sessions[0].id : "";
            }
            return sessions;
        }
        return sessions;
    }
}
