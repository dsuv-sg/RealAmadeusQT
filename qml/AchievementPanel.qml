import QtQuick

Item {
    id: root
    signal closed()
    focus: true

    readonly property string _fontFamily: "Noto Serif CJK JP"
    property var achievements: []

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) return trans[key];
        return defaultValue || key;
    }

    Component.onCompleted: refresh()

    function refresh() {
        if (typeof AchievementManager !== "undefined" && AchievementManager) {
            achievements = AchievementManager.getAllAchievements();
        }
    }

    Connections {
        target: typeof AchievementManager !== "undefined" ? AchievementManager : null
        function onAchievementsChanged() { root.refresh(); }
    }

    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    Text {
        anchors { top: parent.top; left: parent.left; topMargin: 40; leftMargin: 40 }
        text: "ACHIEVEMENTS"
        color: "#FF9900"
        font { family: "MS Mincho"; pixelSize: 64 }
    }

    Text {
        id: progressText
        anchors { top: parent.top; right: parent.right; topMargin: 55; rightMargin: 60 }
        text: {
            if (typeof AchievementManager !== "undefined" && AchievementManager)
                return AchievementManager.unlockedCount + " / " + AchievementManager.totalCount;
            return "0 / 0";
        }
        color: "#FFFFFF"
        font { family: root._fontFamily; pixelSize: 36 }
    }

    ListView {
        id: achievementList
        anchors { top: parent.top; topMargin: 140; left: parent.left; leftMargin: 40; right: parent.right; rightMargin: 40; bottom: parent.bottom; bottomMargin: 150 }
        model: root.achievements
        clip: true
        spacing: 10

        delegate: Rectangle {
            width: achievementList.width
            height: 90
            color: modelData.unlocked ? "#2A2A00" : "#1A1A1A"
            border.color: modelData.unlocked ? "#FF9900" : "#333333"
            border.width: 1

            Rectangle {
                id: achIcon
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                width: 50; height: 50
                radius: 25
                color: modelData.unlocked ? "#FF9900" : "#444444"
                Text {
                    anchors.centerIn: parent
                    text: modelData.unlocked ? "★" : (modelData.secret ? "?" : "☆")
                    color: "#FFFFFF"
                    font.pixelSize: 28
                }
            }

            Column {
                anchors {
                    left: achIcon.right; leftMargin: 20
                    right: achDate.left; rightMargin: 20
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4
                Text {
                    width: parent.width
                    text: modelData.title
                    color: modelData.unlocked ? "#FF9900" : "#888888"
                    font { family: root._fontFamily; pixelSize: 28; bold: true }
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: modelData.description
                    color: modelData.unlocked ? "#FFFFFF" : "#666666"
                    font { family: root._fontFamily; pixelSize: 22 }
                    elide: Text.ElideRight
                }
            }

            Text {
                id: achDate
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                width: 220
                visible: modelData.unlocked && modelData.unlockedAt !== ""
                text: modelData.unlockedAt || ""
                color: "#AAAAAA"
                font { family: root._fontFamily; pixelSize: 18 }
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ─── Close Button (same size/position as other panels) ───
    Rectangle {
        width: 210; height: 70
        color: "#464646"
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        Text {
            anchors.centerIn: parent
            text: t("close", "閉じる")
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 32 }
        }
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) {
            root.closed(); event.accepted = true;
        }
    }

    opacity: 0
    onVisibleChanged: { if (visible) { refresh(); root.opacity = 0; Qt.callLater(function(){ root.opacity = 1; }); } }
    Behavior on opacity { NumberAnimation { duration: 250 } }
    onClosed: { root.opacity = 0; closeTimer.start(); }
    Timer { id: closeTimer; interval: 250; onTriggered: root.visible = false }
}
