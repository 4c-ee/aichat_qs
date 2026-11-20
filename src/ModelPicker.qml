import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root

    property var config
    property var apiClient
    property var settings

    signal modelSelected(string modelId)

    property string cachedModelsEndpoint: ""
    property string cachedModelsKey: ""
    property var cachedModelsList: []
    property bool modelsFetched: false
    property string modelPickerStatus: ""
    property string modelFilterText: ""

    parent: root.config ? null : undefined
    x: 0
    y: -height - 6
    width: Math.min(300, root.config ? root.config.panelWidth : 500)
    padding: 6
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    ListModel { id: filteredModelsModel }

    background: Rectangle {
        radius: root.config.controlRadius
        color: root.config.surfaceColor
        border.color: root.config.outerBorderColor
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 4

        StyledTextField {
            id: modelFilterField
            Layout.fillWidth: true
            config: root.config
            placeholderText: "Filter models..."
            text: root.modelFilterText
            onTextEdited: root.modelFilterText = text
        }

        Text {
            Layout.fillWidth: true
            visible: root.modelPickerStatus !== ""
            text: root.modelPickerStatus
            color: root.config.dangerColor
            font.family: root.config.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: root.modelFilterText.trim() !== ""
                && root.cachedModelsList.length > 0
                && filteredModelsModel.count === 0
            text: "No models match this filter."
            color: root.config.textMuted
            font.family: root.config.fontFamily
            font.pixelSize: 12
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: filteredModelsModel
            clip: true
            spacing: 3

            delegate: ItemDelegate {
                id: modelDelegate
                width: ListView.view.width
                height: 35
                padding: 10

                contentItem: Text {
                    text: model.displayName
                    color: modelDelegate.highlighted
                        ? root.config.accent1Hover
                        : (model.modelId === root.config.modelName ? root.config.accent1 : root.config.textMain)
                    font.family: root.config.fontFamily
                    font.pixelSize: 13
                    font.weight: modelDelegate.highlighted || model.modelId === root.config.modelName
                        ? Font.DemiBold
                        : Font.Normal
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    radius: root.config.controlRadius
                    color: modelDelegate.hovered ? root.config.accent1Hover : "transparent"
                }

                onClicked: {
                    root.config.modelName = model.modelId;
                    root.settings.lastModel = model.modelId;
                    root.modelSelected(model.modelId);
                    root.close();
                }
            }
        }
    }

    Component.onCompleted: {
        root.modelFilterText = "";
        root.refreshModelFilter();
    }

    function show() {
        if (root.opened) {
            root.close();
            return;
        }

        root.modelFilterText = "";
        root.refreshModelFilter();
        var endpoint = root.settings.apiEndpoint.trim();
        var key = root.settings.apiKey.trim();
        if (root.cachedModelsEndpoint !== endpoint || root.cachedModelsKey !== key || !root.modelsFetched) {
            filteredModelsModel.clear();
            root.cachedModelsList = [];
            root.refreshModelFilter();
            root.modelsFetched = false;
            root.modelPickerStatus = "Loading models...";
            root.apiClient.getModels(endpoint, key);
        }
        Popup.open.call(root);
        modelFilterField.forceActiveFocus();
    }

    function refreshModelFilter() {
        filteredModelsModel.clear();
        var filter = root.modelFilterText.trim().toLowerCase();
        root.cachedModelsList.forEach(modelId => {
            var modelName = String(modelId);
            if (filter === "" || modelName.toLowerCase().indexOf(filter) !== -1) {
                filteredModelsModel.append({
                    modelId: modelName,
                    displayName: modelName
                });
            }
        });
    }

    // Connections to apiClient signals
    Connections {
        target: root.apiClient

        function onModelsReceived(models) {
            root.cachedModelsList = models;
            root.refreshModelFilter();
            root.cachedModelsEndpoint = root.settings.apiEndpoint.trim();
            root.cachedModelsKey = root.settings.apiKey.trim();
            root.modelsFetched = true;
            root.modelPickerStatus = models.length === 0 ? "No models returned by this endpoint." : "";
        }

        function onModelsFailed(error) {
            root.modelsFetched = false;
            root.cachedModelsList = [];
            root.refreshModelFilter();
            root.modelPickerStatus = error;
        }
    }
}
