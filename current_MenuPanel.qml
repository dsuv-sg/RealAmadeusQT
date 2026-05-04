import QtQuick
import QtQuick.Controls
import QtQuick.Effects

/// MenuPanel — exact mirror of Unity MenuPanelController.cs
/// All positions are computed from Unity MCP data:
///   MenuPanel: anchoredPos=(150,166), localScale=0.6
///   Canvas: 1920×1080, center=(960,540)
///   screen_x = 960 + (150 + child_x × 0.6)
///   screen_y = 540 − (166 + child_y × 0.6)
///   All x/y below are relative fractions of 1920/1080 so they scale.
Item {
    id: root
    visible: false

    property int  selectedIndex: 0
    property bool menuOpen: false
    property var  backLog: null

    // LLM Status for StatusPanel (passed from Main)
    property string llmProvider: ""
    property string llmModel: ""
    property real   llmLatency: -1
    property bool   isLoggedIn: false
    property int    configLanguage: 0

    property bool isSubPanelOpen: (configPanel ? (configPanel.visible || (root.backLog && root.backLog.visible) || statusPanelMenu.visible || changeLogPanel.visible || helpPanel.visible || confirmDialog.visible) : false)

    signal closeMenuRequested()
    signal logoutRequested()

    function tr(ja, en, zh, ko, es, fr, de, ru) {
        var args = [ja, en, zh, ko, es, fr, de, ru];
        var idx = configLanguage;
        if (idx >= 0 && idx < args.length && args[idx] !== undefined) return args[idx];
        return ja;
    }

    // Scale to actual window from Unity 1920×1080 reference
    readonly property real sx: width  / 1920.0
    readonly property real sy: height / 1080.0

    readonly property string imgBase: "qrc:/qt/qml/RealAmadeusPC/resources/images/"

    function show() {
        if (root.menuOpen) return;
        root.visible  = true;
        root.menuOpen = true;
        bgImage.opacity     = 1;
        menuContent.opacity = 1;
        selectedIndex = 0;
        menuFocus.forceActiveFocus();
    }

    function hide() {
        root.menuOpen = false;
        hideAnim.start();
    }

    // ─── Menu background (Menu.png) ───
    // Unity: center=(270,540), size=640×1080
    Image {
        id: bgImage
        source: imgBase + "Menu.png"
        x: (270 - 320) * root.sx       // center_x - width/2
        y: (540 - 540) * root.sy        // center_y - height/2 = 0
        width:  640 * root.sx
        height: 1080 * root.sy
        fillMode: Image.Stretch
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    // ─── All menu content ───
    Item {
        id: menuContent
        anchors.fill: parent
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        FontLoader {
            id: amadeusFont
            source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/Eurostile Condensed Bold.otf"
        }

        component MenuIcon: Item {
            property int    itemIndex: -1
            property string imgName:   ""
            property real   cx: 0       // screen center x in 1920 coords
            property real   cy: 0       // screen center y in 1080 coords
            property bool   sel: root.selectedIndex === itemIndex
            property real   selScale: 1.0

            x: (cx - 45) * root.sx
            y: (cy - 45) * root.sy
            width:  90 * root.sx
            height: 90 * root.sy

            Image {
                id: iconImg
                source: parent.sel
                    ? (imgBase + parent.imgName + "Selected.png")
                    : (imgBase + parent.imgName + ".png")
                anchors.fill: parent
                fillMode: Image.Stretch
                scale: parent.sel ? parent.selScale : 1.0
                layer.enabled: parent.sel
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 16
                    blur: 0.4
                    brightness: 0.2
                }
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: { root.selectedIndex = parent.itemIndex; root.executeSelection(); }
            }
        }

        // ═══ Positioned text label ═══
        component MenuLabel: Item {
            property int    itemIndex: -1
            property real   cx: 0
            property real   cy: 0
            property bool   sel: root.selectedIndex === itemIndex
            property real   fontSize: 34
            property alias  text: lblText.text
            property int    textAlign: Text.AlignLeft

            x: (cx - 100) * root.sx
            y: (cy - 25) * root.sy
            width:  200 * root.sx
            height: 50  * root.sy

            Text {
                id: lblText
                anchors.fill: parent
                leftPadding: parent.textAlign === Text.AlignLeft ? 40 * root.sx : 0
                font.family:    amadeusFont.status === FontLoader.Ready ? amadeusFont.name : "sans-serif"
                font.pixelSize: Math.round(parent.fontSize * root.sy)
                font.bold:      true
                color: parent.sel ? "#FFFFFF" : "#FFC900"
                horizontalAlignment: parent.textAlign
                verticalAlignment:   Text.AlignVCenter
                lineHeightMode: Text.FixedHeight
                lineHeight:     parent.fontSize === 34 ? Math.round(31 * root.sy) : Math.round(32 * root.sy)
                layer.enabled: parent.sel
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 12
                    blur: 0.3
                    colorizationColor: "#FFFFFF"
                    colorization: 0.2
                    brightness: 0.2
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: { root.selectedIndex = parent.itemIndex; root.executeSelection(); }
            }
        }

        // ═══ 5 main items (icon + label) ═══
        // BackLog: icon(270,146), text(441,147)
        MenuIcon  { itemIndex:0; imgName:"Backlog";   cx:270;  cy:146 }
        MenuLabel { itemIndex:0; text:"BACK\nLOG";    cx:441;  cy:147 }

        // Config: icon(270,320), text(441,321)
        MenuIcon  { itemIndex:1; imgName:"Config";    cx:270;  cy:320 }
        MenuLabel { itemIndex:1; text:"CONFIG";       cx:441;  cy:321 }

        // Status: icon(270,494), text(441,495)
        MenuIcon  { itemIndex:2; imgName:"Status";    cx:270;  cy:494 }
        MenuLabel { itemIndex:2; text:"STATUS";       cx:441;  cy:495 }

        // ChangeLog: icon(270,674), text(441,669)
        MenuIcon  { itemIndex:4; imgName:"ChangeLog"; cx:270;  cy:674 }
        MenuLabel { itemIndex:4; text:"CHANGE\nLOG";  cx:441;  cy:669 }

        // Help: icon(270,848), text(441,843)
        MenuIcon  { itemIndex:6; imgName:"Help";      cx:270;  cy:848 }
        MenuLabel { itemIndex:6; text:"HELP";         cx:441;  cy:843 }

        // ═══ Small text-only items ═══
        // FullScreen/Window toggle: text(135,584)
        MenuLabel {
            itemIndex: 3
            text: (root.Window.window && root.Window.window.visibility === Window.FullScreen)
                  ? "FULL\nSCREEN" : "WINDOW"
            cx: 135; cy: 584; fontSize: 26; textAlign: Text.AlignHCenter
        }

        // Logout: text(135,758)
        MenuLabel { itemIndex:5; text:"LOGOUT";       cx:135;  cy:758;  fontSize:26; textAlign: Text.AlignHCenter }

        // ShutDown: text(135,950)
        MenuLabel { itemIndex:7; text:"SHUT\nDOWN";   cx:135;  cy:950;  fontSize:26; textAlign: Text.AlignHCenter }

        // CloseMenu: text(405,950)
        MenuLabel { itemIndex:8; text:"CLOSE\nMENU";  cx:405;  cy:950;  fontSize:26; textAlign: Text.AlignHCenter }
    }

    // Block pointer input to the menu while any sub-panel is open.
    MouseArea {
        id: subPanelInputBlocker
        anchors.fill: parent
        z: 10
        enabled: root.isSubPanelOpen
        visible: enabled
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        hoverEnabled: true
        onPressed: (mouse) => { mouse.accepted = true; }
        onClicked: (mouse) => { mouse.accepted = true; }
        onReleased: (mouse) => { mouse.accepted = true; }
        onPositionChanged: (mouse) => { mouse.accepted = true; }
        onWheel: (wheel) => { wheel.accepted = true; }
    }

    // ─── Keyboard handler ───
    Item {
        id: menuFocus
        focus: root.visible
        Keys.onPressed: (event) => {
            if (!root.menuOpen) return;
            var up    = (event.key === Qt.Key_W || event.key === Qt.Key_Up);
            var down  = (event.key === Qt.Key_S || event.key === Qt.Key_Down);
            var left  = (event.key === Qt.Key_A || event.key === Qt.Key_Left);
            var right = (event.key === Qt.Key_D || event.key === Qt.Key_Right);
            var enter = (event.key === Qt.Key_Return || event.key === Qt.Key_Enter);
            var back  = (event.key === Qt.Key_Backspace);

            if (back)  { root.closeMenuRequested(); event.accepted = true; return; }
            if (enter) { root.executeSelection(); event.accepted = true; return; }

            var next = root.selectedIndex;
            switch (root.selectedIndex) {
                case 0: if (down) next=1; if (up) next=6; if (right) next=8; break;
                case 1: if (down) next=2; if (up) next=0; if (right) next=8; break;
                case 2: if (down) next=4; if (up) next=1; if (left) next=3; if (right) next=8; break;
                case 3: if (up) next=7; if (left) next=8; if (down) next=5; if (right) next=2; break;
                case 4: if (down) next=6; if (up) next=2; if (right) next=8; if (left) next=5; break;
                case 5: if (right) next=4; if (up) next=3; if (left) next=8; if (down) next=7; break;
                case 6: if (down) next=0; if (up) next=4; if (right) next=8; if (left) next=7; break;
                case 7: if (right) next=6; if (left) next=8; if (up) next=5; if (down) next=3; break;
                case 8: if (right) next=7; if (left) next=6; break;
            }
            if (next !== root.selectedIndex) root.selectedIndex = next;
            event.accepted = true;
        }
    }

    // ─── Actions ───
    function executeSelection() {
        switch (root.selectedIndex) {
            case 0: onBackLog();    break;
            case 1: onConfig();     break;
            case 2: onStatus();     break;
            case 3: onFullscreen(); break;
            case 4: onChangeLog();  break;
            case 5: onLogout();     break;
            case 6: onHelp();       break;
            case 7: onShutdown();   break;
            case 8: root.closeMenuRequested(); break;
        }
    }

    function onBackLog() {
        if (root.backLog) {
            root.backLog.visible = true;
            root.backLog.forceActiveFocus();
            // Connect to restore focus when closed
            var handler = function() {
                menuFocus.forceActiveFocus();
                root.backLog.closed.disconnect(handler);
            };
            root.backLog.closed.connect(handler);
        }
    }
    function onConfig()     { configPanel.visible = true; configPanel.forceActiveFocus(); }
    function onStatus()     { statusPanelMenu.visible = true; statusPanelMenu.forceActiveFocus(); }
    function onChangeLog()  { changeLogPanel.visible = true; changeLogPanel.forceActiveFocus(); }
    function onHelp()       { helpPanel.visible = true; helpPanel.forceActiveFocus(); }
    function onFullscreen() {
        var win = root.Window.window;
        if (!win) return;
        // Toggle via AppSettings so ConfigPanel stays in sync
        var current = AppSettings.getInt("Config_ScreenMode", 0);
        var newMode = (current === 0) ? 1 : 0; // 0=fullscreen, 1=windowed
        AppSettings.setInt("Config_ScreenMode", newMode);
        AppSettings.save();
    }
    function onLogout() {
        confirmDialog.message = root.tr(
            "ログアウトしますか？",
            "Do you want to log out?",
            "您确定要登出吗？",
            "로그아웃하시겠습니까?",
            "¿Quieres cerrar sesión?",
            "Voulez-vous vous déconnecter ?",
            "Möchten Sie sich abmelden?",
            "Вы хотите выйти?"
        );
        confirmDialog.onYes = function() {
            MemoryManager.setUserName("");
            root.logoutRequested();
            root.hide();
        };
        confirmDialog.visible = true;
    }
    function onShutdown() {
        confirmDialog.message = root.tr(
            "リアルアマデウスを終了しますか？",
            "Do you want to exit Real Amadeus?",
            "要退出 Real Amadeus 吗？",
            "Real Amadeus를 종료하시겠습니까?",
            "¿Quieres salir de Real Amadeus?",
            "Voulez-vous quitter Real Amadeus ?",
            "Möchten Sie Real Amadeus beenden?",
            "Выйти из Real Amadeus?"
        );
        confirmDialog.onYes = function() { Qt.quit(); };
        confirmDialog.visible = true;
    }

    // ─── Sub-panels (restore focus on close) ───
    ConfigPanel {
        id: configPanel
        z: 20
        anchors.fill: parent; visible: false
        onClosed: { menuFocus.forceActiveFocus(); }
        configLanguage: root.configLanguage
    }
    StatusPanel {
        id: statusPanelMenu
        z: 20
        anchors.fill: parent; visible: false
        onClosed: { menuFocus.forceActiveFocus(); }
        
        // Bind to MenuPanel's properties
        llmProvider: root.llmProvider
        llmModel:    root.llmModel
        llmLatency:  root.llmLatency
        isLoggedIn:  root.isLoggedIn
        configLanguage: root.configLanguage
    }
    ChangeLogPanel {
        id: changeLogPanel
        z: 20
        anchors.fill: parent; visible: false
        onClosed: { menuFocus.forceActiveFocus(); }
        configLanguage: root.configLanguage
    }
    HelpPanel {
        id: helpPanel
        z: 20
        anchors.fill: parent; visible: false
        onClosed: { menuFocus.forceActiveFocus(); }
        configLanguage: root.configLanguage
    }
    ConfirmationDialog {
        id: confirmDialog
        z: 30
        anchors.centerIn: parent; visible: false
        property string message: ""
        property var    onYes:   null
        dialogMessage: confirmDialog.message
        onConfirmed: { if (onYes) onYes(); closed(); menuFocus.forceActiveFocus(); }
        onCancelled: { closed(); menuFocus.forceActiveFocus(); }
    }

    // ─── Hide animation ───
    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: menuContent; property: "opacity"; to: 0; duration: 200 }
        NumberAnimation { target: bgImage;     property: "opacity"; to: 0; duration: 200 }
        ScriptAction { script: { root.visible = false; root.menuOpen = false; } }
    }
}
