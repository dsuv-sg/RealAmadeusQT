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

    property int configLanguage: AppSettings.getInt("Config_Language", 0)

    FontLoader { id: notoKR; source: "file:///" + appDirPath + "/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) {
            return trans[key];
        }
        return defaultValue || key;
    }


    function mixedTextHtml(text, pixelSize, tighterCyrillic) {
        if (!text) return "";

        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;")
                      .replace(/\n/g, "<br>");
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
            if (code === 0x0406 || code === 0x0456 || code === 0x0407 || code === 0x0457) return "cyrillic_i";
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
                var spacing = (tighterCyrillic && configLanguage === 8) ? "-12.0px" : "-7.0px";
                html += '<span style="font-family: \'MS Mincho\'; letter-spacing: ' + spacing + ';">' + escapeHtml(currentText) + '</span>';
            } else if (currentType === "cyrillic_i") {
                var spacing = (tighterCyrillic && configLanguage === 8) ? "-5.0px" : "-2.0px";
                html += '<span style="font-family: \'MS Mincho\'; letter-spacing: ' + spacing + ';">' + escapeHtml(currentText) + '</span>';
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

    // Wrap Hangul runs in <font face> for StyledText (MS Mincho for everything else)
    function styledText(text) {
        if (!text) return "";
        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        }
        function isHangul(c) {
            var code = c.charCodeAt(0);
            return (code >= 0xAC00 && code <= 0xD7AF) || (code >= 0x1100 && code <= 0x11FF) || (code >= 0x3130 && code <= 0x318F);
        }
        var result = "";
        var run = "";
        var runHangul = false;
        for (var i = 0; i < text.length; i++) {
            var ch = text[i];
            var chHangul = isHangul(ch);
            if (run.length > 0 && chHangul !== runHangul) {
                var face = runHangul ? (notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR") : "MS Mincho";
                result += '<font face="' + face + '">' + escapeHtml(run) + '</font>';
                run = "";
            }
            run += ch;
            runHangul = chHangul;
        }
        if (run.length > 0) {
            var face = runHangul ? (notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR") : "MS Mincho";
            result += '<font face="' + face + '">' + escapeHtml(run) + '</font>';
        }
        return result;
    }

    // BackLog name rendering:
    // - Russian only: Cyrillic runs use letter-spacing -9.4px
    // - Other languages: default spacing
    function styledNameText(text) {
        if (!text) return "";
        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        }
        function isHangul(c) {
            var code = c.charCodeAt(0);
            return (code >= 0xAC00 && code <= 0xD7AF) || (code >= 0x1100 && code <= 0x11FF) || (code >= 0x3130 && code <= 0x318F);
        }
        function isCyrillicI(c) {
            var code = c.charCodeAt(0);
            return (code === 0x0406 || code === 0x0456 || code === 0x0407 || code === 0x0457);
        }
        function isCyrillic(c) {
            var code = c.charCodeAt(0);
            return (code >= 0x0400 && code <= 0x04FF && !isCyrillicI(c));
        }
        function charType(c) {
            if (isHangul(c)) return "hangul";
            if (configLanguage === 7 || configLanguage === 8) {
                if (isCyrillic(c)) return "cyrillic";
                if (isCyrillicI(c)) return "cyrillic_i";
            }
            return "other";
        }

        var result = "";
        var run = "";
        var runType = "other";

        function flush() {
            if (run.length === 0) return;
            if (runType === "hangul") {
                var family = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";
                result += '<font face="' + family + '">' + escapeHtml(run) + '</font>';
            } else if (runType === "cyrillic") {
                result += '<span style="font-family: \'MS Mincho\'; letter-spacing: -8.0px;">' + escapeHtml(run) + '</span>';
            } else if (runType === "cyrillic_i") {
                result += '<span style="font-family: \'MS Mincho\'; letter-spacing: -3.0px;">' + escapeHtml(run) + '</span>';
            } else {
                result += '<font face="MS Mincho">' + escapeHtml(run) + '</font>';
            }
            run = "";
        }

        for (var i = 0; i < text.length; i++) {
            var ch = text[i];
            var type = charType(ch);
            if (run.length > 0 && type !== runType) {
                flush();
            }
            if (run.length === 0) runType = type;
            run += ch;
        }
        flush();
        return result;
    }

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") { configLanguage = AppSettings.getInt("Config_Language", 0); }
        }
    }

    // Unity parity values (BackLogController.cs)
    readonly property int entrySidePadding: 20
    readonly property int entryVerticalPadding: 5
    readonly property int nameColumnWidth: 115
    readonly property int columnSpacing: 150
    readonly property int minEntryHeight: 40
    readonly property int backlogFontSize: 26

    function addLog(role, message) {
        var clean = message.trim();
        if (clean.startsWith("[")) {
            var closeBracket = clean.indexOf("]");
            if (closeBracket > 0) clean = clean.substring(closeBracket + 1).trim();
        }
        clean = clean.replace(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/gi, "").trim();
        if (clean.length === 0) return;

        var nameColor;
        var roleId = role.toLowerCase();
        switch (roleId) {
            case "user": case "me": nameColor = "#66CCFF"; break;
            case "assistant": case "kurisu": case "amadeus": nameColor = "#FF6666"; break;
            default: nameColor = "#808080"; break;
        }
        logModel.append({ "role": roleId, "nameColor": nameColor, "msg": clean });
        if (root.visible) Qt.callLater(scrollToBottom);
    }

    function scrollToBottom() {
        logFlickable.contentY = Math.max(0, logFlickable.contentHeight - logFlickable.height);
    }

    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    Item {
        id: headerRect
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 35; leftMargin: 50; rightMargin: 50 }
        height: 80
        Text {
            id: backlogTitle
            height: parent.height
            anchors { left: parent.left; top: parent.top }
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

    Flickable {
        id: logFlickable
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 170; leftMargin: 90; rightMargin: 90; bottomMargin: 180 }
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, logColumn.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: logColumn
            width: logFlickable.width
            y: Math.max(0, logFlickable.height - height)
            spacing: 30

            Repeater {
                model: ListModel { id: logModel }
                delegate: Item {
                    width: logColumn.width
                    height: Math.max(root.minEntryHeight, messageText.implicitHeight + root.entryVerticalPadding * 2)
                    Rectangle { anchors.fill: parent; color: "transparent" }

                    Row {
                        height: parent.height
                        anchors { fill: parent; leftMargin: root.entrySidePadding; rightMargin: root.entrySidePadding; topMargin: root.entryVerticalPadding; bottomMargin: root.entryVerticalPadding }
                        spacing: root.columnSpacing

                        Text {
                            id: nameText
                            width: root.nameColumnWidth
                            height: parent.height
                            anchors.top: parent.top; anchors.topMargin: 5
                            text: {
                                switch (model.role) {
                                    case "user": case "me": return styledNameText(t("you", "あなた"));
                                    case "assistant": case "kurisu": case "amadeus": return styledNameText(t("amadeus_kurisu", "アマデウス紅莉栖"));
                                    case "system": return "SYSTEM";
                                    default: return model.role.toUpperCase();
                                }
                            }
                            textFormat: Text.RichText
                            color: model.nameColor
                            font { family: "MS Mincho"; pixelSize: root.backlogFontSize; bold: true }
                            wrapMode: Text.NoWrap
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignTop
                        }

                        Text {
                            id: messageText
                            width: Math.max(1, parent.width - root.nameColumnWidth - root.columnSpacing)
                            height: parent.height
                            anchors.top: parent.top; anchors.topMargin: 5
                            text: styledText(model.msg)
                            textFormat: Text.RichText
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

    T.ScrollBar {
        id: vBar
        width: 10
        policy: T.ScrollBar.AsNeeded
        visible: logFlickable.contentHeight > logFlickable.height
        parent: root
        x: logFlickable.x + logFlickable.width + 30
        y: logFlickable.y
        height: logFlickable.height
        padding: 0; topPadding: 0; bottomPadding: 0
        orientation: Qt.Vertical
        size: logFlickable.visibleArea.heightRatio
        position: logFlickable.visibleArea.yPosition
        background: Rectangle { color: "#FFFFFF" }
        contentItem: Rectangle { implicitWidth: 10; color: "#FF9900" }
        onPositionChanged: { if (active) logFlickable.contentY = position * logFlickable.contentHeight; }
    }

    // ─── Close Button ───
    Rectangle {
        width: 210; height: 70
        color: "#464646"
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        Text {
            anchors.centerIn: parent
            text: mixedTextHtml(t("close", "閉じる"), font.pixelSize, true)
            color: "#FFFFFF"
            textFormat: Text.RichText
            font.pixelSize: 32
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Keys.onPressed: (event) => { if (event.key === Qt.Key_Backspace) { root.closed(); event.accepted = true; } }

    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
    onVisibleChanged: {
        if (visible) {
            root.opacity = 0;
            Qt.callLater(function() { root.opacity = 1; scrollToBottom(); });
        }
    }
    onClosed: { root.opacity = 0; closeTimer.start(); }
    Timer { id: closeTimer; interval: 200; onTriggered: root.visible = false }
}
