import QtQuick
import Quickshell.Io

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
                                data: collectorAudio.text.trim(),
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
}
