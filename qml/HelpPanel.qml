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

    FontLoader { id: notoKR; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(ja, en, zh, ko, es, fr, de, ru) {
        switch(configLanguage) {
            case 0: return ja;
            case 1: return en;
            case 2: return zh;
            case 3: return ko;
            case 4: return es;
            case 5: return fr;
            case 6: return de;
            case 7: return ru;
            default: return ja;
        }
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

            HelpEntry { title: "Tab / " + t("右クリック", "Right Click", "右键", "우클릭", "Clic derecho", "Clic droit", "Rechtsklick", "Правый клик"); desc: t("メニュー開閉", "Toggle Menu", "打开/关闭菜单", "메뉴 열기/닫기", "Abrir/cerrar menú", "Ouvrir/fermer menu", "Menü umschalten", "Открыть/закрыть меню") }
            HelpEntry { title: "Backspace"; desc: t("保存して閉じる", "Save and Close", "保存并关闭", "저장하고 닫기", "Guardar y cerrar", "Sauvegarder et fermer", "Speichern und schließen", "Сохранить и закрыть") }
            HelpEntry { title: "WASD / ↑←↓→"; desc: t("項目選択", "Select Item", "选择项目", "항목 선택", "Seleccionar elemento", "Sélectionner", "Element auswählen", "Выбор элемента") }
            HelpEntry { title: "Enter"; desc: t("決定 / 会話を進める", "Confirm / Advance", "确认 / 推进对话", "결정 / 대화 진행", "Confirmar / Avanzar", "Confirmer / Avancer", "Bestätigen / Fortfahren", "Подтвердить / Продолжить") }
        }
    }

    // ─── Close Button ───
    Rectangle {
        width: 210; height: 70
        color: "#464646"
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        Text {
            anchors.centerIn: parent
            text: mixedTextHtml(t("閉じる", "Close", "关闭", "닫기", "Cerrar", "Fermer", "Schließen", "Закрыть"), 32)
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
