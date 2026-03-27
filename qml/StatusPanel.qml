import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// StatusPanel - mirrors StatusPanelController.cs
/// Unity: Header(SYSTEM STATUS 64px #FF9900), Clock(54px #FFF), InfoGrid(6 rows), Credits(24px #808080)
Item {
    id: root
    signal closed()
    focus: true

    property string llmProvider: ""
    property string llmModel: ""
    property real   llmLatency: -1

    // Called by ChatPanel after each API response
    function updateLLMStats(provider, model, latencyMs) {
        root.llmProvider = provider;
        root.llmModel    = model;
        root.llmLatency  = latencyMs;
    }

    // ─── Background ───
    // Unity: Image component, sprite=Amadeus_BG.png, type=Simple, color=(1,1,1,1)
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    // ─── Header ───
    // Unity: anchoredPos=(960,-70) from top-left, size=1820×80, text="SYSTEM STATUS"
    // Font: MSMINCHO 64px, color=#FF9900 (r:1.0 g:0.6 b:0.0), hAlign=Left, vAlign=Middle
    Item {
        id: headerItem
        // Unity offsetMin.x=50, offsetMax.x=1870, so left=50, right=1920-1870=50
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
    // Unity: anchoredPos=(600,-60) from center-top, size=1820×80
    // Font: MSMINCHO 54px, color=#FFFFFF, hAlign=Center, vAlign=Middle
    // In 1920-based coords: top = 60 - 40 = 20, left = 960 + 600 - 910 = 650
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
    // Unity: anchoredPos=(960,-325) from top-left, size=1820×330
    // offsetMin.x=50 → left=50, offsetMax.x=1870 → right=1920-1870=50
    // top = 325 - 165 = 160, bottom = top + 330 = 490
    Item {
        id: infoGrid
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 160
        anchors.leftMargin: 50
        anchors.rightMargin: 50
        height: 330

        // ─── LeftCol ───
        // Unity: localPos=(-490,0) relative to InfoGrid center, size=837×330
        // InfoGrid center.x = 910, so LeftCol center.x = 910 - 490 = 420
        // LeftCol left = 420 - 418.5 = 1.5 ≈ 2
        // VLG spacing=15, 6 rows × 100h = 600 + 5×15 = 675
        Column {
            id: leftCol
            anchors { left: parent.left; leftMargin: 2; top: parent.top }
            width: 837
            spacing: 65

            // Row_SYSTEM_VERSION (HLG spacing=20, label minWidth=250, value flex=1)
            StatusRow { label: "SYSTEM_VERSION"; value: "Real Amadeus v1.1Q" }
            // Row_LIVE2D_MODEL
            StatusRow { label: "LIVE2D_MODEL"; value: "Live2DKurisu v1.0" }
            // Row_OPERATOR
            StatusRow { label: "OPERATOR"; value: MemoryManager.userName.length > 0 ? MemoryManager.userName : "---" }
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
                value: root.llmProvider.length > 0
                       ? root.llmProvider + " / " + root.llmModel
                       : AppSettings.getString("Config_ApiProvider", "0") + " / (未確認)"
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
    // Unity: localPos=(0,-510) from StatusPanel center, size=1820×40
    // Font: MSMINCHO 24px, color=#808080. Alignment: Left, Bottom (Horizontal: 1, Vertical: 1024)
    // 5-line text. Container bottom is 10px from screen bottom.
    Text {
        anchors { left: parent.left; leftMargin: 50; bottom: parent.bottom; bottomMargin: 10 }
        width: 1820
        text: "Provided by ELVELT/Real Amadeus Project\nDeveloped by DSUV\nDesigned by DSUV/Amane\nThis project is a derivative work of Steins;Gate 0\nVersion 1.1Q(Build 20260319_002)"
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
    // Unity: HorizontalLayoutGroup spacing=20, row height=100
    // Child 1 (Label): LayoutElement minWidth=250, preferredWidth=250, fontSize=32, color=#FF9900
    // Child 2 (Value): LayoutElement flexibleWidth=1, fontSize=32 (autoSize), color=#FFFFFF
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
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 18
                clip: true
            }
        }
    }
}
