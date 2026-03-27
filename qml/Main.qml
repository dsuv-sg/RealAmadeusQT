import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: mainWindow
    width:  1920
    height: 1080
    minimumWidth:  800
    minimumHeight: 450
    visible: true
    visibility: Window.FullScreen
    title: "Amadeus System"
    color: "#000000"

    // ─── State machine ───
    // "login" ↁE"boot" ↁE"chat"
    property string appState: "login"

    // Auto Mode (F3)
    property bool autoMode: AppSettings.getInt("Config_AutoMode", 0) === 1
    property real autoSpeed: AppSettings.getFloat("Config_AutoSpeed", 3.0)

    // Language setting for reactive UI
    property int configLanguage: AppSettings.getInt("Config_Language", 0)

    // Tab Window Toggle State
    property bool isTabActive: false

    // Global LLM Status (mirrors Unity StatusPanelController)
    property string llmProvider: ""
    property string llmModel: ""
    property real   llmLatency: -1

    function applyScreenSettings() {
        var screenMode = AppSettings.getInt("Config_ScreenMode", 0);
        var resIdx = AppSettings.getInt("Config_Resolution", 0);
        
        var w = 1920, h = 1080;
        if (resIdx === 0) { w = 1920; h = 1080; }
        else if (resIdx === 1) { w = 1600; h = 900; }
        else if (resIdx === 2) { w = 1280; h = 720; }

        if (screenMode === 0) {
            // FullScreen  Euse plain Qt.Window flag for true fullscreen
            mainWindow.flags = Qt.Window;
            mainWindow.minimumWidth = 0;
            mainWindow.maximumWidth = 16384;
            mainWindow.minimumHeight = 0;
            mainWindow.maximumHeight = 16384;
            mainWindow.visibility = Window.FullScreen;
        } else {
            // Windowed  Edisable resize/maximize via custom flags
            mainWindow.flags = Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint
                       | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint
                       | Qt.WindowCloseButtonHint;
            mainWindow.visibility = Window.Windowed;
            mainWindow.width = w;
            mainWindow.height = h;
            mainWindow.minimumWidth = w;
            mainWindow.maximumWidth = w;
            mainWindow.minimumHeight = h;
            mainWindow.maximumHeight = h;

            // Center on resolution change
            mainWindow.x = (Screen.width - w) / 2;
            mainWindow.y = (Screen.height - h) / 2;
        }
    }

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_ScreenMode" || key === "Config_Resolution") {
                applyScreenSettings();
                return;
            }

            if (key === "Config_AutoMode") {
                mainWindow.autoMode = AppSettings.getInt("Config_AutoMode", 0) === 1;
                return;
            }

            if (key === "Config_AutoSpeed") {
                mainWindow.autoSpeed = AppSettings.getFloat("Config_AutoSpeed", 3.0);
            }

            if (key === "Config_Language") {
                mainWindow.configLanguage = AppSettings.getInt("Config_Language", 0);
            }
        }
    }

    // ─── Global UI scaling ───
    // All UI is designed for 1920ÁE080. When the window is smaller,
    // we scale the contentItem so proportions are preserved.
    readonly property real uiScale: mainWindow.width / 1920.0

    // Apply scale to the Window's implicit content container.
    // This does NOT conflict with child-level scale/x/y (e.g. SystemPanel Tab anim).
    Component.onCompleted: {
        contentItem.transform = [scaleXform];
        applyScreenSettings();
    }
    Scale {
        id: scaleXform
        xScale: mainWindow.uiScale
        yScale: mainWindow.uiScale
        origin.x: 0
        origin.y: 0
    }

    // ─── Key handling ───
    Shortcut {
        sequence: "F11"
        onActivated: {
            var current = AppSettings.getInt("Config_ScreenMode", 0);
            AppSettings.setInt("Config_ScreenMode", current === 0 ? 1 : 0);
            AppSettings.save();
        }
    }
    Shortcut {
        sequence: "F3"
        onActivated: {
            mainWindow.autoMode = !mainWindow.autoMode;
            AppSettings.setInt("Config_AutoMode", mainWindow.autoMode ? 1 : 0);
            AppSettings.save();
        }
    }

    Shortcut {
        sequence: "Tab"
        onActivated: {
            if (menuPanel.isSubPanelOpen) return;
            mainWindow.isTabActive = !mainWindow.isTabActive
        }
    }

    // ─── BackLog Panel (Shared) ───
    BackLogPanel {
        id: mainBackLog
        z: 100
        visible: false
        width: 1920
        height: 1080
        configLanguage: mainWindow.configLanguage
    }

    // ─── System Panel ───
    SystemPanel {
        id: systemPanel
        width: 1920
        height: 1080
        enabled: !mainWindow.isTabActive

        appState: mainWindow.appState
        autoMode: mainWindow.autoMode
        autoSpeed: mainWindow.autoSpeed
        configLanguage: mainWindow.configLanguage
        isTabActive: mainWindow.isTabActive
        backLog: mainBackLog

        onLoginAccepted: mainWindow.appState = "boot"
        onBootFinished: mainWindow.appState = "chat"
        onOpenMenuRequested: menuPanel.show()
        
        onSystemAnimProgressChanged: {
            if (mainWindow.isTabActive && systemAnimProgress >= 0.95 && !menuPanel.menuOpen) {
                menuPanel.show();
            } else if (!mainWindow.isTabActive && menuPanel.menuOpen) {
                menuPanel.hide();
            }
        }
    }

    // ─── Menu Panel ───
    MenuPanel {
        id: menuPanel
        width: 1920
        height: 1080
        z: 99
        backLog: mainBackLog
        llmProvider: mainWindow.llmProvider
        llmModel:    mainWindow.llmModel
        llmLatency:  mainWindow.llmLatency
        isLoggedIn:  mainWindow.appState === "chat"
        configLanguage: mainWindow.configLanguage
        onCloseMenuRequested: mainWindow.isTabActive = false
        onLogoutRequested: {
            mainWindow.appState = "login";
            mainWindow.isTabActive = false;
        }
    }

    // ─── Global Mouse Interaction ───
    MouseArea {
        x: 0
        y: 0
        width: mainWindow.width
        height: mainWindow.height
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (AppSettings.getInt("Config_RightClickMenu", 1) === 1) {
                if (menuPanel.isSubPanelOpen) return;
                mainWindow.isTabActive = !mainWindow.isTabActive;
            }
        }
    }
}
