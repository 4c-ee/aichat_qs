import QtQuick
import Quickshell.Io
import "ProcessHelper.js" as ProcessHelper

QtObject {
    id: root

    // Process a list of attachment file paths into API content parts.
    // Results are delivered via callback(array) once all files are processed.
    function process(files, callback) {
        if (files.length === 0) {
            callback([]);
            return;
        }

        var results = new Array(files.length);
        var completed = 0;

        function checkCompletion() {
            completed++;
            if (completed === files.length) {
                callback(results.filter(r => r !== undefined));
            }
        }

        files.forEach((file, index) => {
            if (file.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
                ProcessHelper.runCommand(root, ["base64", "-w", "0", file], function(encodedData) {
                    if (encodedData !== "") {
                        var mimeType = "image/jpeg";
                        if (file.match(/\.png$/i)) mimeType = "image/png";
                        else if (file.match(/\.gif$/i)) mimeType = "image/gif";
                        else if (file.match(/\.webp$/i)) mimeType = "image/webp";

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
                });
            } else if (file.match(/\.(wav|mp3|ogg|m4a)$/i)) {
                ProcessHelper.runCommand(root, ["base64", "-w", "0", file], function(encodedData) {
                    if (encodedData !== "") {
                        var format = "wav";
                        if (file.match(/\.mp3$/i)) format = "mp3";
                        else if (file.match(/\.ogg$/i)) format = "ogg";
                        else if (file.match(/\.m4a$/i)) format = "m4a";

                        results[index] = {
                            type: "input_audio",
                            input_audio: {
                                data: encodedData,
                                format: format
                            }
                        };
                    }

                    checkCompletion();
                });
            } else {
                ProcessHelper.runCommand(root, ["cat", file], function(text) {
                    if (text !== "") {
                        var fileName = file.split('/').pop();
                        results[index] = {
                            type: "text",
                            text: "\n--- Attached File: " + fileName + " ---\n" + text + "\n--- End Attachment ---"
                        };
                    }

                    checkCompletion();
                });
            }
        });
    }
}
