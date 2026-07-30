import QtQuick
import QtQuick.Controls

Item {
    id: systemPanelRoot

    property string appState: "login"
    property bool autoMode: false
    property real autoSpeed: 3.0
    property bool isTabActive: false
    property bool menuPanelOpen: false
    property real systemAnimProgress: 0.0
    property var  backLog: null

    signal loginAccepted()
    signal bootFinished()
    signal openMenuRequested()
    property alias chatPanel: chatPanel

    property int configLanguage: AppSettings.getInt("Config_Language", 0)

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

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") { configLanguage = AppSettings.getInt("Config_Language", 0); }
        }
    }

    // Bind transforms to progress
    scale: 1.0 + (0.6 - 1.0) * systemAnimProgress
    x: 150 * systemAnimProgress
    y: -12 * systemAnimProgress

    // Tab animation targets (Default Item.Center origin matches Unity center pivot behavior)
    transformOrigin: Item.Center

    NumberAnimation {
        id: tabAnimation
        target: systemPanelRoot
        property: "systemAnimProgress"
        duration: Math.abs(tabAnimation.to - systemPanelRoot.systemAnimProgress) * 500
        easing.type: Easing.Linear
    }

    onIsTabActiveChanged: {
        tabAnimation.stop();
        tabAnimation.to = isTabActive ? 1.0 : 0.0;
        tabAnimation.start();
    }

    Image {
        id: menuBackground
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/RealAmadeus_Menu_BG_v3.jpg"
        scale: 1.666667
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -250
        anchors.verticalCenterOffset: 20
        z: -1
        //fillMode: Image.PreserveAspectFit
        // Important: Remove anchors.fill: parent as it conflicts with explicitly sized/centered layout
        width: 1920
        height: 1080
    }

    // ─── Title Bar (custom, shown instead of OS bar in fullscreen) ───
    Rectangle {
        id: titleBar
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 35
        color: "#c8c8c8"
        z: 10

        Text {
            anchors.centerIn: parent
            text: "Amadeus.system"
            color: "#464646"
            font.pixelSize: 22
            font.family: titleFont.status === FontLoader.Ready ? titleFont.name : "Liberation Sans"
            verticalAlignment: TextInput.AlignVCenter
        }
    }

    // ─── Background image ────────────────────────────────────────────
    Image {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.PreserveAspectCrop
    }

    // ─── Login Screen ───
    LoginPanel {
        id: loginPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: systemPanelRoot.appState === "login"
        onLoginAccepted: {
            systemPanelRoot.loginAccepted()
        }
    }

    // ─── Boot Sequence (Now LoadingPanel) ───
    Loader {
        id: bootLoader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        active: systemPanelRoot.appState === "boot"
        sourceComponent: Component {
            LoadingPanel {
                anchors.fill: parent
                onBootFinished: {
                    systemPanelRoot.bootFinished()
                }
            }
        }
    }

    // ─── Chat Screen ───
    Item {
        id: chatScreen
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: systemPanelRoot.appState === "chat"
        opacity: 0

        Behavior on opacity { NumberAnimation { duration: 500 } }

        onVisibleChanged: {
            if (visible) opacity = 1;
        }

        ChatPanel {
            id: chatPanel
            anchors.fill: parent
            autoMode: systemPanelRoot.autoMode
            autoSpeed: systemPanelRoot.autoSpeed
            backLog: systemPanelRoot.backLog
            configLanguage: systemPanelRoot.configLanguage
            menuPanelOpen: systemPanelRoot.menuPanelOpen
            chatScreenActive: systemPanelRoot.appState === "chat"
            onOpenMenu: systemPanelRoot.openMenuRequested()
        }
        Text {
            visible: systemPanelRoot.autoMode
            width: 200
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenterOffset: 800
            anchors.verticalCenterOffset: -427.5
            text: "Auto"
            color: "#ff9900"
            font { family: "Noto Serif CJK JP"; weight: Font.Light; pixelSize: 70 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ─── Global fonts ───
    FontLoader { id: monoFont; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/Eurostile Condensed Bold.otf" }
    FontLoader { id: titleFont; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/LiberationSans.ttf" }
}
