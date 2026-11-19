.pragma library

function escapeHtml(text) {
    var amp = String.fromCharCode(38);
    return String(text)
        .replace(/&/g, amp + "amp;")
        .replace(/</g, amp + "lt;")
        .replace(/>/g, amp + "gt;");
}

function formatMessage(text) {
    if (!text) return "";

    var formatted = escapeHtml(text);
    var protectedBlocks = [];

    // Protect code first so markdown and HTML inside it remain literal.
    formatted = formatted.replace(/```([\s\S]*?)```/g, function(match, code) {
        var token = "%%AICHAT_CODEBLOCK_" + protectedBlocks.length + "%%";
        protectedBlocks.push('<pre style="color:#b6cacc; padding:8px; background-color:#33000000;">' + code.trim() + "</pre>");
        return token;
    });

    var protectedInlineCode = [];
    formatted = formatted.replace(/`([^`]+)`/g, function(match, code) {
        var token = "%%AICHAT_INLINECODE_" + protectedInlineCode.length + "%%";
        protectedInlineCode.push('<code style="color:#c0f8fc; padding:2px;">' + code + "</code>");
        return token;
    });

    // Inline emphasis. Bold and bold-italic use the icy accent color.
    formatted = formatted.replace(/\*\*\*([^*]+)\*\*\*/g, '<b><i><font color="#c0f8fc">$1</font></i></b>');
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<b><font color="#c0f8fc">$1</font></b>');
    formatted = formatted.replace(/\*([^*\n]+)\*/g, "<i>$1</i>");
    formatted = formatted.replace(/~~([^~]+)~~/g, "<s>$1</s>");

    // Block-level markdown.
    formatted = formatted.replace(/^### (.*$)/gm, '<h3 style="color:#c0f8fc;">$1</h3>');
    formatted = formatted.replace(/^## (.*$)/gm, '<h2 style="color:#c0f8fc;">$1</h2>');
    formatted = formatted.replace(/^# (.*$)/gm, '<h1 style="color:#c0f8fc;">$1</h1>');
    formatted = formatted.replace(/^---$/gm, "<hr/>");
    formatted = formatted.replace(/^\*\*\*$/gm, "<hr/>");

    formatted = formatted.replace(/^\|(.+)\|$/gm, function(match, content) {
        var cells = content.split("|").map(function(cell) {
            return '<td style="color:#e0fafc; padding:5px;">' + cell.trim() + "</td>";
        }).join("");
        return "<tr>" + cells + "</tr>";
    });
    formatted = formatted.replace(/((?:<tr>.*<\/tr>\n?)+)/g, '<table style="border-collapse:collapse; margin:10px 0;">$1</table>');
    formatted = formatted.replace(/<tr>(?:\s*<td>\s*[:\-]+\s*<\/td>\s*)+<\/tr>/g, "");

    formatted = formatted.replace(/^[\*-] (.*$)/gm, "<li>$1</li>");
    formatted = formatted.replace(/((?:<li>.*<\/li>\n?)+)/g, "<ul>$1</ul>");

    formatted = formatted.replace(/\n/g, "<br/>");
    formatted = formatted.replace(/(<\/(?:h1|h2|h3|ul|li|table|tr|pre|hr)>)<br\/>/g, "$1");

    protectedInlineCode.forEach(function(block, index) {
        formatted = formatted.replace("%%AICHAT_INLINECODE_" + index + "%%", block);
    });
    protectedBlocks.forEach(function(block, index) {
        formatted = formatted.replace("%%AICHAT_CODEBLOCK_" + index + "%%", block);
    });

    return formatted;
}

// Remove the prompt instructions used by the legacy, text-based tool system.
// The implementation is intentionally kept in the repository so it can be
// replaced by an official OpenAI-compatible tools implementation later.
function stripLegacyToolInstructions(text) {
    if (!text) return "";

    var legacyToolSection = /\n\n# Tool Use\nYou can call tools by outputting tool\["\(tool_name\)", "input1", "input2"\]\.\nThe tool call MUST be at the end of your response\.\n\nAvailable tools:\n- tool\["search", "query"\]:[^\n]*\n- tool\["getpage", "url", "prompt"\]:[^\n]*/g;
    return String(text).replace(legacyToolSection, "").replace(/\s+$/, "");
}

// Remove a trailing legacy tool invocation from an assistant message.
function stripLegacyToolCall(text) {
    if (!text) return "";

    var legacyToolCall = /\n*tool\["([^"]+)"(?:,\s*"([^"]*)")?(?:,\s*"([^"]*)")?\]\s*$/;
    return String(text).replace(legacyToolCall, "").replace(/\s+$/, "");
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
        content.forEach(function(item) {
            if (item.type === "text") result += item.text;
            else if (item.type === "image_url") result += "\n[Image Attachment]";
            else if (item.type === "input_audio") result += "\n[Audio Attachment]";
        });
        return result;
    }
    return String(content);
}
