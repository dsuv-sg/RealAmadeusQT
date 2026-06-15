import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal confirmed()
    signal cancelled()
    signal closed()

    property string dialogMessage: ""
    property int    selectedIndex: 0 // 0: YES, 1: NO
    property int    configLanguage: AppSettings.getInt("Config_Language", 0)

    FontLoader { id: notoKR; source: "file:///" + appDirPath + "/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) {
            return trans[key];
        }
        return defaultValue || key;
    }


    // ─── Mixed-font HTML generator (per-character script detection) ───
    // Hangul → Noto Serif, Other → MS Mincho
    // If applyRussianSpacing is true, Cyrillic uses tighter letter spacing.
    function mixedTextHtml(text, pixelSize, applyRussianSpacing) {
        if (!text) return "";
        if (applyRussianSpacing === undefined) applyRussianSpacing = true;

        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;")
                      .replace(/\r\n|\r|\n/g, "<br>");
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
                } else if (applyRussianSpacing && segFont === "MS Mincho") {
                    var runHtml = "";
                    var curType = "";
                    var curText = "";
                    
                    function flushRun() {
                        if (curText.length === 0) return;
                        if (curType === "cyrillic") {
                            var spacing = (root.configLanguage === 8) ? "-12.0px" : "-8.0px";
                            runHtml += '<span style="font-family: \'MS Mincho\'; letter-spacing: ' + spacing + ';">' + escapeHtml(curText) + '</span>';
                        } else if (curType === "cyrillic_i") {
                            var spacing = (root.configLanguage === 8) ? "-7.0px" : "-5.0px";
                            runHtml += '<span style="font-family: \'MS Mincho\'; letter-spacing: ' + spacing + ';">' + escapeHtml(curText) + '</span>';
                        } else {
                            runHtml += '<span style="font-family: \'MS Mincho\';">' + escapeHtml(curText) + '</span>';
                        }
                        curText = "";
                    }
                    
                    for (var j = 0; j < segText.length; j++) {
                        var c = segText[j];
                        var code = c.charCodeAt(0);
                        var type = "other";
                        if (code === 0x0406 || code === 0x0456 || code === 0x0407 || code === 0x0457) {
                            type = "cyrillic_i";
                        } else if (code >= 0x0400 && code <= 0x04FF) {
                            type = "cyrillic";
                        }
                        
                        if (type !== curType && curText.length > 0) {
                            flushRun();
                        }
                        if (curText.length === 0) curType = type;
                        curText += c;
                    }
                    flushRun();
                    html += runHtml;
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
            if (applyRussianSpacing && (code === 0x0406 || code === 0x0456 || code === 0x0407 || code === 0x0457)) return "cyrillic_i";
            if (applyRussianSpacing && code >= 0x0400 && code <= 0x04FF) return "cyrillic";
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
                var spacing = (root.configLanguage === 8) ? "-12.0px" : "-8.0px";
                html += '<span style="font-family: \'MS Mincho\'; letter-spacing: ' + spacing + ';">' + escapeHtml(currentText) + '</span>';
            } else if (currentType === "cyrillic_i") {
                var spacing = (root.configLanguage === 8) ? "-7.0px" : "-5.0px";
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

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") { root.configLanguage = AppSettings.getInt("Config_Language", 0); }
        }
    }

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#1A1A1A"
        opacity: 0.7 * root.opacity
    }

    Item {
        id: dialogBox
        anchors.centerIn: parent
        width: 800
        height: 300

        Rectangle {
            anchors.fill: parent
            color: "#1A1A1A"

            border.color: "#FFC900"
            border.width: 1
        }


        Text {
            id: dialogMessageText

            height: 80
            topPadding: -40
            anchors.centerIn: parent
            Layout.fillWidth: true
            color: "#FFFFFF"
            verticalAlignment: Text.AlignTop
            horizontalAlignment: Text.AlignHCenter

            text: mixedTextHtml(root.dialogMessage, 36, true)
            textFormat: Text.RichText
        }

        Rectangle {
            id: yesButtonImage
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 200
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 100
            width: 200
            height: 60
            color: root.selectedIndex === 0 ? "#ffc900" : "#404040"

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) root.selectedIndex = 0;
                }
            }

            Text {
                id: yesButtonText
                anchors.centerIn: parent
                enabled: false
                text: mixedTextHtml(t("yes", "はい"), 30)
                textFormat: Text.RichText
                color: root.selectedIndex === 0 ? "#000000" : "#FFFFFF"
                font.pixelSize: 30
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { root.selectedIndex = 0; }
                onPressed: { root.selectedIndex = 0; }
                onClicked: { root.confirmed(); }
            }
        }

        Rectangle {
            id: noButtonImage
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -200
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 100
            width: 200
            height: 60
            color: root.selectedIndex === 1 ? "#ffc900" : "#404040"

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) root.selectedIndex = 1;
                }
            }

            Text {
                id: noButtonText
                anchors.centerIn: parent
                enabled: false
                text: mixedTextHtml(t("no", "いいえ"), 30)
                textFormat: Text.RichText
                color: root.selectedIndex === 1 ? "#000000" : "#FFFFFF"
                font.pixelSize: 30
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { root.selectedIndex = 1; }
                onPressed: { root.selectedIndex = 1; }
                onClicked: { root.cancelled(); }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
            root.selectedIndex = 1;
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
            root.selectedIndex = 0;
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedIndex === 0) root.confirmed();
            else root.cancelled();
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Backspace) {
            root.cancelled();
            event.accepted = true;
        }
    }

    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 200 } }  // 0.2s = 200ms

    onVisibleChanged: {
        if (visible) {
            root.opacity = 0;
            root.selectedIndex = 0;
            root.forceActiveFocus();
            Qt.callLater(() => root.opacity = 1);
        }
    }

    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }

    Timer {
        id: closeTimer
        interval: 200
        onTriggered: root.visible = false
    }
}
