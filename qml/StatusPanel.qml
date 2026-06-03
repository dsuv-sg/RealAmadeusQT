import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// StatusPanel - mirrors StatusPanelController.cs
Item {
    id: root
    signal closed()
    focus: true

    property string llmProvider: ""
    property string llmModel: ""
    property real   llmLatency: -1
    property bool   isLoggedIn: false
    property int    configLanguage: AppSettings.getInt("Config_Language", 0)
    FontLoader { id: notoKR; source: "file:///" + Qt.application.dirPath + "/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) {
            return trans[key];
        }
        return defaultValue || key;
    }


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
            if (key === "Config_Language") configLanguage = AppSettings.getInt("Config_Language", 0);
        }
    }

    // Called by ChatPanel after each API response
    function updateLLMStats(provider, model, latencyMs) {
        root.llmProvider = provider;
        root.llmModel    = model;
        root.llmLatency  = latencyMs;
    }

    // ─── Background ───
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    // ─── Header ───
    Item {
        id: headerItem
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 30
        anchors.leftMargin: 50
        anchors.rightMargin: 50
        height: 80

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "SYSTEM STATUS"
            color: "#FF9900"
            font { family: "MS Mincho"; pixelSize: 64 }
        }

        // Unity: Header has child Separator (line at bottom)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            color: "#FF9900"
        }
    }

    // ─── Clock ───
    Text {
        id: clockText
        anchors { top: parent.top; topMargin: 20 }
        // Unity: center.x = parentCenter.x + 600 = 960 + 600 = 1560
        // rect left = 1560 - 910 = 650
        x: 650
        width: 1820; height: 80
        text: clockTimer.clockTextValue
        color: "#FFFFFF"
        font { family: "MS Mincho"; pixelSize: 54 }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // ─── InfoGrid ───
    Item {
        id: infoGrid
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 160
        anchors.leftMargin: 50
        anchors.rightMargin: 50
        height: 330

        // ─── LeftCol ───
        Column {
            id: leftCol
            anchors { left: parent.left; leftMargin: 2; top: parent.top }
            width: 837
            spacing: 65

            // Row_SYSTEM_VERSION (HLG spacing=20, label minWidth=250, value flex=1)
            StatusRow { label: "SYSTEM_VERSION"; value: "Real Amadeus v1.2Q(Build 20260504_001)" }
            // Row_LIVE2D_MODEL
            StatusRow { label: "LIVE2D_MODEL"; value: "Live2DKurisu v1.0" }
            // Row_OPERATOR
            StatusRow { label: "OPERATOR"; value: root.isLoggedIn ? (MemoryManager.userName.length > 0 ? MemoryManager.userName : "Salieri") : "---" }
            // Row_NETWORK
            StatusRow {
                label: "NETWORK"
                value: root.networkReachable
                       ? "<font color='#44FF44'>ONLINE</font>"
                       : "<font color='#FF4444'>OFFLINE</font>"
            }
            // Row_LLMMODEL
            StatusRow {
                label: "LLM_MODEL"
                value: {
                    // Unity parity: keep initial placeholder until first LLM stats update.
                    if (root.llmProvider.length === 0 || root.llmModel.length === 0) return "---";
                    return root.llmProvider + " / " + root.llmModel;
                }
            }
            // Row_AVERAGE_LATENCY
            StatusRow {
                label: "AVERAGE_LATENCY"
                value: {
                    if (root.llmLatency < 0) return "--- ms";
                    var color = "#44FF44"; // green
                    if (root.llmLatency > 3000) color = "#FF4444"; // red
                    else if (root.llmLatency > 1000) color = "#FFFF44"; // yellow
                    return "Ping: <font color='" + color + "'>" + root.llmLatency.toFixed(0) + " ms</font>";
                }
            }
        }
    }

    // ─── Credits ───

    Text {
        anchors { left: parent.left; leftMargin: 50; bottom: parent.bottom; bottomMargin: 10 }
        width: 1820
        text: "Provided by ELVELT/Real Amadeus Project\nDeveloped by DSUV\nDesigned by DSUV/Amane\nThis project is a derivative work of Steins;Gate 0\nVersion 1.2Q(Build 20260504_001)"
        color: "#808080"
        font { family: "MS Mincho"; pixelSize: 24 }
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignBottom
        lineHeight: 1.0
    }

    // ─── Clock timer ───
    Timer {
        id: clockTimer
        property string clockTextValue: ""
        function updateTime() {
            clockTextValue = Qt.formatDateTime(new Date(), "yyyy/MM/dd HH:mm:ss")
        }
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: updateTime()
    }

    onVisibleChanged: {
        if (visible) {
            root.opacity = 0;
            Qt.callLater(function(){ root.opacity = 1; });
            clockTimer.updateTime();
        }
    }

    // ─── Network check (simple ping via XMLHttpRequest) ───
    property bool networkReachable: true
    Timer {
        interval: 5000; repeat: true; running: root.visible
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.timeout = 3000;
            xhr.open("HEAD", "https://www.google.com");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE)
                    root.networkReachable = (xhr.status > 0);
            };
            xhr.onerror = function() { root.networkReachable = false; };
            try { xhr.send(); } catch(e) { root.networkReachable = false; }
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

    // ─── Fade ───
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 250 } }


    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.visible = false
    }

    // ─── StatusRow component ───
    component StatusRow: Item {
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 837
        height: 50  // Unity row height is 100 but text uses 50px sizeDelta

        Row {
            anchors.fill: parent
            spacing: 20

            Text {
                text: label
                color: "#FF9900"
                font { family: "MS Mincho"; pixelSize: 32 }
                width: 250
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                clip: true
            }
            Text {
                text: value
                textFormat: Text.StyledText
                color: "#FFFFFF"
                font { family: "MS Mincho"; pixelSize: 32 }
                width: parent.width - 250 - 20
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                //fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 18
                //clip: true
            }
        }
    }

}
