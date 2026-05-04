import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates as T

/// HelpPanel - mirrors Unity HelpPanelController.cs
Item {
    id: root
    signal closed()
    focus: true

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
            topMargin: 60; leftMargin: 100; rightMargin: 100
        }
        height: 80

        Text {
            id: headerTitle
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "HELP"
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

    // ─── Log list ───
    ScrollView {
        id: helpScroll
        anchors {
            top: headerRect.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 70; leftMargin: 140; rightMargin: 140; bottomMargin: 70
        }
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: helpScroll.availableWidth
            spacing: 40

            component HelpEntry: Column {
                property string title: ""
                property string desc: ""
                width: parent.width
                spacing: 10

                Text { height: 50; text: title; color: "#FF9900"; font { family: "MS Mincho"; pixelSize: 36 } horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignTop; }
                Rectangle { width: parent.width; height: 1; color: "#FF9900";}
                Text { text: desc; color: "#E6E6E6"; font { family: "MS Mincho"; pixelSize: 28 } }
            }

            HelpEntry { title: "Tab / 右クリック"; desc: "メニュー開閉" }
            HelpEntry { title: "Backspace"; desc: "保存して閉じる" }
            HelpEntry { title: "WASD / ↑←↓→"; desc: "項目選択" }
            HelpEntry { title: "Enter"; desc: "決定 / 会話を進める" }
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
    Behavior on opacity { NumberAnimation { duration: 250 } }
    onVisibleChanged: { if (visible) { root.opacity = 0; Qt.callLater(function(){ root.opacity = 1; }); } }

    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.visible = false
    }
    Behavior on opacity { NumberAnimation { duration: 200 } }
}
