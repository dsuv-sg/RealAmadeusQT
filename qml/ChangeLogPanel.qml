import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T

Item {
    id: root
    width: 1920
    height: 1080
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


    function v12Text() {
        return t("changelog_v12", "中国語/韓国語/スペイン語/フランス語/ドイツ語/ロシア語 のサポートを追加しました。\n視線トラッキングを追加しました。\nデスクトップ通知機能を実装しました。\n軽量化モードを追加しました。\nAlt+Enter、F11 での画面モード切替を実装しました。\nAPIプロバイダーにOllamaとOpenRouterを追加しました。\nUIのバグを修正しました。\nAPIキーのセキュリティを向上させました。\nパフォーマンスを改善しました。");
    }

    function v11Text() {
        return t("changelog_v11", "メニュー画面의 클릭 선택을 구현했습니다.");
    }

    function v101Text() {
        return t("changelog_v101", "GPU사용률이 비정상적으로 높아지는 문제를 수정했습니다.");
    }

    function v10Text() {
        return t("changelog_v10", "Real Amadeus의 최초 버전을 릴리스했습니다.");
    }

    // ─── Mixed-font HTML generator (per-character script detection) ───
    // Hangul → Noto Serif, Cyrillic → MS Mincho + letterSpacing -6.4, Other → MS Mincho
    function mixedTextHtml(text, pixelSize) {
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
        id: backgroundImage
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    // ─── Header area ───
    Item {
        id: headerRect
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 80; leftMargin: 100; rightMargin: 100; bottomMargin: 30;
        }
        height: 60

        Text {
            id: headerTitle
            anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 12 }
            text: "CHANGE LOG"
            color: "#FF9900"
            font { family: "MS Mincho"; pixelSize: 64; bold: false }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            color: "#FF9900"
        }
    }



    // ─── Log content ───
    ScrollView {
        id: logScroll
        anchors {
            top: headerRect.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 40; leftMargin: 140; rightMargin: 140; bottomMargin: 160
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
                color: "#FFFFFF"
            }
            contentItem: Rectangle {
                implicitWidth: 10
                color: "#FF9900"
            }
        }
        Flickable {
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: parent.width
            contentHeight: contentColumn.implicitHeight
            Column {
                id: contentColumn
                width: logScroll.width
                spacing: 36
                topPadding: 10
                bottomPadding: 40

                // Version 1.2
                Column {
                    width: logScroll.width
                    Item {
                        width: logScroll.width
                        height: 50

                        Text {
                            y: 4
                            text: "Version 1. 2"
                            color: "#FF9900"
                            font.family: "MS Mincho"
                            font.pixelSize: 36
                            font.bold: true
                            font.letterSpacing: 1.75
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom

                        }
                        Text {
                            x: 450
                            y: 12
                            text: "2026. 05. 04"
                            color: "#808080"
                            font.family: "MS Mincho"
                            font.pixelSize: 28
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom
                        }
                    }

                    Rectangle {
                        width: logScroll.width
                        height: 1
                        color: "#FF9900"
                    }

Text {
                        topPadding: 10
                        width: logScroll.width
                        text: mixedTextHtml(v12Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
                        font.pixelSize: 28
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 42
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignTop

                    }
                }

                // Version 1.1
                Column {
                    width: logScroll.width
                    Item {
                        width: logScroll.width
                        height: 50

                        Text {
                            y: 4
                            text: "Version 1. 1"
                            color: "#FF9900"
                            font.family: "MS Mincho"
                            font.pixelSize: 36
                            font.bold: true
                            font.letterSpacing: 1.75
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom

                        }
                        Text {
                            x: 450
                            y: 12
                            text: "2026. 03. 21"
                            color: "#808080"
                            font.family: "MS Mincho"
                            font.pixelSize: 28
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom
                        }
                    }

                    Rectangle {
                        width: logScroll.width
                        height: 1
                        color: "#FF9900"
                    }

                    Text {
                        topPadding: 10
                        width: logScroll.width
                        text: mixedTextHtml(v11Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
                        font.pixelSize: 28
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 42
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignTop

                    }
                }

                // Version 1.0.1
                Column {
                    width: logScroll.width
                    Item {
                        width: logScroll.width
                        height: 50

                        Text {
                            y: 4
                            text: "Version 1. 0 .1"
                            color: "#FF9900"
                            font.family: "MS Mincho"
                            font.pixelSize: 36
                            font.bold: true
                            font.letterSpacing: 1.75
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom

                        }
                        Text {
                            x: 450
                            y: 12
                            text: "2026. 02. 23"
                            color: "#808080"
                            font.family: "MS Mincho"
                            font.pixelSize: 28
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom
                        }
                    }

                    Rectangle {
                        width: logScroll.width
                        height: 1
                        color: "#FF9900"
                    }

                    Text {
                        topPadding: 10
                        width: logScroll.width
                        text: mixedTextHtml(v101Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
                        font.pixelSize: 28
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 42
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignTop

                    }
                }

                // Version 1.0
                Column {
                    width: logScroll.width

                    Item {
                        width: logScroll.width
                        height: 50

                        Text {
                            y: 4
                            text: "Version 1. 0"
                            color: "#FF9900"
                            font.family: "MS Mincho"
                            font.pixelSize: 36
                            font.bold: true
                            font.letterSpacing: 1.75
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom

                        }
                        Text {
                            x: 450
                            y: 12
                            text: "2026. 02. 22"
                            color: "#808080"
                            font.family: "MS Mincho"
                            font.pixelSize: 28
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignBottom
                        }
                    }

                    Rectangle {
                        width: logScroll.width
                        height: 1
                        color: "#FF9900"
                    }

                    Text {
                        topPadding: 10
                        width: logScroll.width
                        text: mixedTextHtml(v10Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
                        font.pixelSize: 28
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 42
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignTop
                    }
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
            text: mixedTextHtml(t("close", "閉じる"), font.pixelSize)
            color: "#FFFFFF"
            textFormat: Text.RichText
            font.pixelSize: 32
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
    onVisibleChanged: { 
        if (visible) { 
            root.opacity = 0; 
            Qt.callLater(function(){ root.opacity = 1; }); 
        } 
    }

    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.visible = false
    }
}
