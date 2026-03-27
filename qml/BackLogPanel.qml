import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates as T

/// BackLogPanel - mirrors BackLogController.cs
/// Scrollable conversation history with color-coded roles.
/// Unity layout: single-line rich text per entry with "<b>Name</b>　Message"
/// FontSize=26, padding(20,5), minHeight=40, ContentSizeFitter
Item {
    id: root
    signal closed()
    focus: true
    property int configLanguage: AppSettings.getInt("Config_Language", 0)

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") {
                root.configLanguage = AppSettings.getInt("Config_Language", 0);
            }
        }
    }

    // Unity parity values (BackLogController.cs)
    readonly property int entrySidePadding: 20
    readonly property int entryVerticalPadding: 5
    readonly property int nameColumnWidth: 115
    readonly property int columnSpacing: 150
    readonly property int minEntryHeight: 40
    readonly property int backlogFontSize: 26

    // Call this from ChatPanel / MenuPanel to log a message
    function addLog(role, message) {
        // Strip emotion tags (Unity parity: strip leading [TAG])
        var clean = message.trim();
        if (clean.startsWith("[")) {
            var closeBracket = clean.indexOf("]");
            if (closeBracket > 0) {
                clean = clean.substring(closeBracket + 1).trim();
            }
        }
        // Also strip any remaining emotion tags via regex
        clean = clean.replace(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/gi, "").trim();
        if (clean.length === 0) return;

        var nameColor;
        var roleId = role.toLowerCase();
        switch (roleId) {
            case "user": case "me":
                nameColor = "#66CCFF"; break;
            case "assistant": case "kurisu": case "amadeus":
                nameColor = "#FF6666"; break;
            case "system":
                nameColor = "#808080"; break;
            default:
                nameColor = "#808080"; break;
        }

        logModel.append({ "role": roleId, "nameColor": nameColor, "msg": clean });

        // Auto-scroll to bottom (Unity: ScrollToBottom coroutine)
        if (root.visible) {
            Qt.callLater(scrollToBottom);
        }
    }

    function scrollToBottom() {
        logFlickable.contentY = Math.max(0, logFlickable.contentHeight - logFlickable.height);
    }

    // ─── Background ───
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    // ─── Header area ───
    Item {
        id: headerRect
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 35; leftMargin: 50; rightMargin: 50
        }
        height: 80

        FontLoader {
            id: amadeusFont
            source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/Eurostile Condensed Bold.otf"
        }

        Text {
            id: backlogTitle
            height: parent.height
            anchors { left: parent.left; top: parent.top; }
            text: "BACKLOG"
            color: "#FF9900"
            font { family: "MS Mincho"; pixelSize: 64 }
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            color: "#FF9900"
        }
    }

    // ─── Log list (Flickable for Unity ScrollRect parity) ───
    Flickable {
        id: logFlickable
        anchors {
            top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 170; leftMargin: 90; rightMargin: 90; bottomMargin: 180
        }
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, logColumn.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: logColumn
            width: logFlickable.width
            // When there are only a few lines, keep them visually at the bottom.
            y: Math.max(0, logFlickable.height - height)
            spacing: 30 // Unity: VerticalLayoutGroup, entries handle their own padding

            Repeater {
                model: ListModel { id: logModel }
                delegate: Item {
                    width: logColumn.width
                    // Unity: ContentSizeFitter + LayoutElement minHeight=40
                    height: Math.max(root.minEntryHeight, messageText.implicitHeight + root.entryVerticalPadding * 2)
                    // Unity: Background Image with alpha=0 (transparent)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    // Unity equivalent: horizontal layout with fixed name column + message column.
                    Row {
                        height: parent.height
                        anchors {
                            fill: parent
                            leftMargin: root.entrySidePadding; rightMargin: root.entrySidePadding
                            topMargin: root.entryVerticalPadding; bottomMargin: root.entryVerticalPadding
                        }
                        spacing: root.columnSpacing

                        // Name column (fixed width)
                        Text {
                            id: nameText
                            text: {
                                var en = root.configLanguage === 1;
                                switch (model.role) {
                                    case "user": case "me":
                                        return en ? "You" : "あなた";
                                    case "assistant": case "kurisu": case "amadeus":
                                        return en ? "Amadeus Kurisu" : "アマデウス紅莉栖";
                                    case "system":
                                        return "SYSTEM";
                                    default:
                                        return model.role.toUpperCase();
                                }
                            }
                            color: model.nameColor
                            width: root.nameColumnWidth
                            height: parent.height

                            anchors.top: parent.top
                            anchors.topMargin: 5

                            font { family: "MS Mincho"; pixelSize: root.backlogFontSize; bold: true }
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignTop
                        }

                        // Message column (wraps within remaining width)
                        Text {
                            id: messageText
                            width: Math.max(1,
                                            parent.width
                                            - root.nameColumnWidth
                                            - root.columnSpacing)
                            height: parent.height


                            anchors.top: parent.top
                            anchors.topMargin: 5

                            text: model.msg
                            color: "#FFFFFF"
                            font { family: "MS Mincho"; pixelSize: root.backlogFontSize }
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignTop
                        }
                    }
                }
            }
        }
    }

    // ─── Scrollbar (custom, matching existing style) ───
    T.ScrollBar {
        id: vBar
        width: 10
        policy: T.ScrollBar.AsNeeded
        visible: logFlickable.contentHeight > logFlickable.height
        parent: root
        x: logFlickable.x + logFlickable.width + 30
        y: logFlickable.y
        height: logFlickable.height
        padding: 0
        topPadding: 0
        bottomPadding: 0
        orientation: Qt.Vertical
        size: logFlickable.visibleArea.heightRatio
        position: logFlickable.visibleArea.yPosition

        background: Rectangle {
            color: "#FFFFFF"

        }
        contentItem: Rectangle {
            implicitWidth: 10
            color: "#FF9900"
        }

        onPositionChanged: {
            if (active) {
                logFlickable.contentY = position * logFlickable.contentHeight;
            }
        }
    }

    // ─── Close Button ───
    Rectangle {
        width: 210; height: 70
        color: "#464646"
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        Text {
            anchors.centerIn: parent
            text: root.configLanguage === 1 ? "Close" : "閉じる"
            color: "#FFFFFF"
            font { family: "MS Mincho"; pixelSize: 32 }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    // ─── Keyboard: Backspace to close (Unity parity) ───
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace) { root.closed(); event.accepted = true; }
    }

    // ─── Fade in/out (Unity: fadeDuration=0.2s) ───
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    onVisibleChanged: {
        if (visible) {
            root.opacity = 0;
            // Unity: LayoutRebuilder + ScrollToBottom on Show()
            Qt.callLater(function() {
                root.opacity = 1;
                scrollToBottom();
            });
        }
    }

    // ─── Closing logic ───
    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: 200  // Unity: fadeDuration = 0.2s
        onTriggered: root.visible = false
    }
}
