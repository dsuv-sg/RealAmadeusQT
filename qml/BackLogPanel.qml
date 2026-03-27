import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates as T

/// BackLogPanel - mirrors BackLogController.cs
/// Scrollable conversation history with color-coded roles.
Item {
    id: root
    signal closed()
    focus: true

    // Call this from ChatPanel / MenuPanel to log a message
    function addLog(role, message) {
        // Strip emotion tags
        var clean = message.replace(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/gi, "").trim();
        if (clean.length === 0) return;

        var namePrefix, nameColor;
        switch (role.toLowerCase()) {
            case "user": case "me":
                namePrefix = "あなた"; nameColor = "#66ccff"; break;
            case "assistant": case "kurisu": case "amadeus":
                namePrefix = "紅莉栖";  nameColor = "#ff6666"; break;
            default:
                namePrefix = "SYSTEM"; nameColor = "#888888"; break;
        }

        logModel.append({ "namePrefix": namePrefix, "nameColor": nameColor, "msg": clean });
        Qt.callLater(function() {
            logScroll.contentY = Math.max(0, logScroll.contentHeight - logScroll.height);
        });
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
            topMargin: 30; leftMargin: 50; rightMargin: 50
        }
        height: 80

        Text {
            id: backlogTitle
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "BACKLOG"
            color: "#FFFFFF"
            font { family: "MS Mincho"; pixelSize: 64 }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            color: "#FF9900"
        }
    }

    // ─── Log list ───
    ScrollView {
        id: logScroll
        anchors {
            top: headerRect.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 40; leftMargin: 50; rightMargin: 50; bottomMargin: 150
        }
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: T.ScrollBar {
            id: vBar
            width: 10
            policy: T.ScrollBar.AlwaysOn
            parent: root
            x: logScroll.x + logScroll.width + 30
            y: logScroll.y
            height: logScroll.height
            padding: 0
            topPadding: 0
            bottomPadding: 0

            background: Rectangle {
                color: "#FF9900"
            }
            contentItem: Rectangle {
                implicitWidth: 10
                color: "#FFFFFF"
            }
        }

        Component.onCompleted: {
            flickableItem.boundsBehavior = Flickable.StopAtBounds
        }

        Column {
            id: logColumn
            width: logScroll.availableWidth
            spacing: 20

            Repeater {
                model: ListModel { id: logModel }
                delegate: Column {
                    width: logColumn.width
                    spacing: 5

                    Text {
                        text: model.namePrefix
                        color: model.nameColor || "#FF9900"
                        font { family: "MS Mincho"; pixelSize: 28 }
                    }

                    Text {
                        width: parent.width
                        text: model.msg
                        color: "#FFFFFF"
                        font { family: "MS Mincho"; pixelSize: 24 }
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                    }

                    // Bottom margin for the entry
                    Item { width: 1; height: 10 }
                }
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
            text: "閉じる"
            color: "#FFFFFF"
            font { family: "MS Mincho"; pixelSize: 32 }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace) { root.closed(); event.accepted = true; }
    }

    // ─── Fade in/out ───
    opacity: 0
    onVisibleChanged: { if (visible) { root.opacity = 0; Qt.callLater(function(){ root.opacity = 1; }); } }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // ─── Closing logic ───
    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.visible = false
    }
    // Simple fade via visible property - just use opacity directly
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
}
