import QtQuick
import QtQuick.Layouts

Item {
    id: root
    
    property string title: ""
    property color borderColor: "#c5c5c5"
    default property alias frameContent: contentContainer.data
    property Item rightElement: null
    property real titlePadding: 10
    property Flickable stickyScroll: null
    property var config: null
    
    readonly property real stickyY: {
        if (!stickyScroll || !stickyScroll.contentItem) return 0;
        var scrollView = stickyScroll;
        var scrollContent = scrollView.contentItem;
        var map = root.mapToItem(scrollContent, 0, 0);
        var offset = scrollView.contentY - map.y;
        return Math.max(0, Math.min(root.height - root.headerHeight - 40, offset));
    }
    
    implicitWidth: 400
    implicitHeight: Math.max(
        (borderRect.anchors.topMargin + 10),
        (contentContainer.y + contentContainer.implicitHeight + 15),
        (root.headerHeight + 20)
    )
    
    // Calculate header height based on title or right element
    readonly property real headerHeight: Math.max(
        title !== "" ? titleText.implicitHeight : 0,
        rightElement !== null ? (rightElement.implicitHeight || rightElement.height || 0) : 0,
        14 // Minimum header height for border alignment
    )
    
    Rectangle {
        id: borderRect
        anchors.fill: parent
        anchors.topMargin: Math.round(root.headerHeight / 2)
        color: "transparent"
        border.color: root.borderColor
        border.width: 1
        z: 0
    }
    
    Item {
        id: contentContainer
        x: 12
        anchors.top: parent.top
        anchors.topMargin: root.headerHeight + 10
        width: parent.width - 24
        height: implicitHeight
        implicitHeight: childrenRect.height
        clip: false 
        z: 1
    }
    
    onRightElementChanged: {
        if (root.rightElement) {
            root.rightElement.parent = rightElementBackground;
            root.rightElement.anchors.centerIn = undefined; // Clear any existing anchors
            root.rightElement.anchors.centerIn = rightElementBackground;
        }
    }
    
    // Left Label (Title)
    Rectangle {
        id: titleBackground
        x: 12
        y: root.stickyY
        width: titleText.implicitWidth + root.titlePadding * 2
        height: root.headerHeight
        color: "black"
        visible: root.title !== ""
        z: 2
        
        Text {
            id: titleText
            anchors.centerIn: parent
            text: root.title
            color: root.borderColor
            font.family: root.config ? root.config.fontFamily : "Monospace"
            font.pixelSize: 12
        }
    }
    
    // Right Element Container
    Rectangle {
        id: rightElementBackground
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: root.stickyY
        width: root.rightElement ? (root.rightElement.implicitWidth || root.rightElement.width) + root.titlePadding * 2 : 0
        height: root.headerHeight
        color: "black"
        visible: root.rightElement !== null
        z: 2
    }
}
