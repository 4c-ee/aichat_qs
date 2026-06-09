// Simple API client for OpenAI-compatible endpoints

function sendMessage(endpoint, apiKey, model, messages, onResponse, onError) {
    var xhr = new XMLHttpRequest();
    var url = endpoint + "/chat/completions";
    
    xhr.open("POST", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            console.log("XHR Done. Status:", xhr.status);
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var content = response.choices[0].message.content;
                    onResponse(content);
                } catch (e) {
                    onError("Failed to parse response: " + e.message);
                }
            } else if (xhr.status === 0) {
                onError("Network Error: Request failed (status 0). Check your internet connection or the API endpoint URL.");
            } else {
                onError("API Error (" + xhr.status + "): " + xhr.responseText);
            }
        }
    };

    xhr.onerror = function() {
        console.log("XHR Error event triggered");
        onError("Network Error: The request could not be completed.");
    };

    var data = JSON.stringify({
        model: model,
        messages: messages
    });
    
    xhr.send(data);
}
