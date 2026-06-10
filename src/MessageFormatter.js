.pragma library

function formatMessage(text) {
    if (!text) return "";

    var formatted = text.replace(/&/g, "&")
                        .replace(/</g, "<")
                        .replace(/>/g, ">");

    formatted = formatted.replace(/```([\s\S]*?)```/g, function(match, code) {
        return '<pre style="padding: 5px; border: 1px solid #404040;">' + code.trim() + '</pre>';
    });

    formatted = formatted.replace(/`([^`]+)`/g, '<code style="padding: 2px; border: 1px solid #404040;">$1</code>');

    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");

    formatted = formatted.replace(/\*([^*]+)\*/g, "<i>$1</i>");

    formatted = formatted.replace(/~~([^~]+)~~/g, "<s>$1</s>");

    formatted = formatted.replace(/^### (.*$)/gm, "<h3>$1</h3>");
    formatted = formatted.replace(/^## (.*$)/gm, "<h2>$1</h2>");
    formatted = formatted.replace(/^# (.*$)/gm, "<h1>$1</h1>");

    formatted = formatted.replace(/^---$/gm, "<hr/>");
    formatted = formatted.replace(/^\*\*\*$/gm, "<hr/>");

    formatted = formatted.replace(/^\|(.+)\|$/gm, function(match, content) {
        var cells = content.split('|').map(function(c) { return '<td style="border: 1px solid #404040; padding: 5px;">' + c.trim() + "</td>"; }).join('');
        return "<tr>" + cells + "</tr>";
    });
    formatted = formatted.replace(/((?:<tr>.*<\/tr>\n?)+)/g, '<table style="border-collapse: collapse; margin: 10px 0;">$1</table>');
    formatted = formatted.replace(/<tr>(?:\s*<td>\s*[:\-]+\s*<\/td>\s*)+<\/tr>/g, "");

    formatted = formatted.replace(/^[\*-] (.*$)/gm, "<li>$1</li>");
    formatted = formatted.replace(/((?:<li>.*<\/li>\n?)+)/g, "<ul>$1</ul>");

    formatted = formatted.replace(/\n/g, "<br/>");
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