import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Templates as T

/// HelpPanel - mirrors Unity HelpPanelController.cs
Item {
    id: root
    signal closed()
    focus: true

    property int configLanguage: AppSettings.getInt("Config_Language", 0)

    FontLoader { id: notoKR; source: "file:///" + Qt.application.dirPath + "/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) {
            return trans[key];
        }
        return defaultValue || key;
    }


    // ─── Mixed-font HTML generator (per-character script detection) ───
    // Hangul → Noto Serif, Cyrillic → MS Mincho + letterSpacing -6.4, Other → MS Mincho
    function mixedTextHtml(text, pixelSize) {
        if (!text) return "";

        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;");
        }

        if (Array.isArray(text)) {
            var html = "";
            for (var i = 0; i < text.length; i++) {
                var seg = text[i];
                var segText = seg.text || "";
                var segFont = seg.font || "MS Mincho";
                var segSpacing = seg.letterSpacing !== undefined ? seg.letterSpacing : 0.0;
                
                if (segFont === "Noto Serif CJK KR" || segFont === "Noto Serif CJK") {
                    var family = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";
                    html += '<span style="font-family: \'' + family + '\';">' + escapeHtml(segText) + '</span>';
                } else if (segSpacing !== 0.0) {
                    html += '<span style="font-family: \'' + segFont + '\'; letter-spacing: ' + segSpacing + 'px;">' + escapeHtml(segText) + '</span>';
                } else {
                    html += '<span style="font-family: \'' + segFont + '\';">' + escapeHtml(segText) + '</span>';
                }
            }
            return '<span style="font-size: ' + pixelSize + 'px;">' + html + '</span>';
        }

        function charType(c) {
            var code = c.charCodeAt(0);
            if (code >= 0xAC00 && code <= 0xD7AF) return "hangul";
            if (code >= 0x1100 && code <= 0x11FF) return "hangul";
            if (code >= 0x3130 && code <= 0x318F) return "hangul";
            if (code >= 0x0400 && code <= 0x04FF) return "cyrillic";
            return "other";
        }

        var html = "";
        var currentType = "";
        var currentText = "";

        function flush() {
            if (currentText.length === 0) return;
            if (currentType === "hangul") {
                var family = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";
                html += '<span style="font-family: \'' + family + '\';">' + escapeHtml(currentText) + '</span>';
            } else if (currentType === "cyrillic") {
                html += '<span style="font-family: \'MS Mincho\'; letter-spacing: -8.4px;">' + escapeHtml(currentText) + '</span>';
            } else {
                html += '<span style="font-family: \'MS Mincho\';">' + escapeHtml(currentText) + '</span>';
            }
            currentText = "";
        }

        for (var i = 0; i < text.length; i++) {
            var c = text[i];
            var type = charType(c);
            if (type !== currentType && currentText.length > 0) {
                flush();
            }
            if (currentText.length === 0) currentType = type;
            currentText += c;
        }
        flush();

        return '<span style="font-size: ' + pixelSize + 'px;">' + html + '</span>';
    }

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") { configLanguage = AppSettings.getInt("Config_Language", 0); }
        }
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

                Text { height: 50; text: mixedTextHtml(title, 36); color: "#FF9900"; font.pixelSize: 36; textFormat: Text.RichText; horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignTop; }
                Rectangle { width: parent.width; height: 1; color: "#FF9900";}
                Text { text: mixedTextHtml(desc, 28); color: "#E6E6E6"; font.pixelSize: 28; textFormat: Text.RichText }
            }

            HelpEntry { title: "Tab / " + t("help_right_click", "右クリック"); desc: t("help_toggle_menu", "メニュー開閉") }
            HelpEntry { title: "Backspace"; desc: t("help_save_close", "保存して閉じる") }
            HelpEntry { title: "WASD / ↑←↓→"; desc: t("help_select_item", "項目選択") }
            HelpEntry { title: "Enter"; desc: t("help_confirm_advance", "決定 / 会話を進める") }
        }
    }

    // ─── Close Button ───
    Rectangle {
        width: 210; height: 70
        color: "#464646"
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        Text {
            anchors.centerIn: parent
            text: mixedTextHtml(t("close", "閉じる"), 32)
            color: "#FFFFFF"
            font.pixelSize: 32
            textFormat: Text.RichText
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
