import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: mainWindow
    width:  1920
    height: 1080
    minimumWidth:  800
    minimumHeight: 450
    visible: true
    title: "Amadeus System"
    color: "#000000"

    // Apply saved screen mode on startup
    visibility: AppSettings.getInt("Config_ScreenMode", 0) === 0 ? Window.FullScreen : Window.Windowed

    function centerWindow() {
        if (mainWindow.visibility !== Window.Windowed) return;

        var s = mainWindow.screen;
        if (!s) return;

        var gx = 0;
        var gy = 0;
        var gw = s.width;
        var gh = s.height;

        if (s.availableGeometry) {
            gx = s.availableGeometry.x;
            gy = s.availableGeometry.y;
            gw = s.availableGeometry.width;
            gh = s.availableGeometry.height;
        } else if (s.virtualGeometry) {
            gx = s.virtualGeometry.x;
            gy = s.virtualGeometry.y;
            gw = s.virtualGeometry.width;
            gh = s.virtualGeometry.height;
        }

        mainWindow.x = Math.round(gx + (gw - mainWindow.width) / 2);
        mainWindow.y = Math.round(gy + (gh - mainWindow.height) / 2);
    }

    function applyScreenSettings() {
        var screenMode = AppSettings.getInt("Config_ScreenMode", 0);
        // 0 = Fullscreen, 1 = Windowed
        if (screenMode === 0) {
            mainWindow.visibility = Window.FullScreen;
        } else {
            mainWindow.visibility = Window.Windowed;
        }

        // Apply resolution (only when not fullscreen)
        var resIdx = AppSettings.getInt("Config_Resolution", 0);
        var w = 1920, h = 1080;
        if (resIdx === 1) { w = 1600; h = 900; }
        else if (resIdx === 2) { w = 1280; h = 720; }
        if (screenMode !== 0) {
            mainWindow.width = w;
            mainWindow.height = h;
            Qt.callLater(mainWindow.centerWindow);
        }
    }

    onVisibilityChanged: {
        if (mainWindow.visibility === Window.Windowed) {
            Qt.callLater(mainWindow.centerWindow);
        }
    }

    // ─── State machine ───
    // "login" → "boot" → "chat"
    property string appState: "login"

    // Auto Mode (F3)
    property bool autoMode: AppSettings.getInt("Config_AutoMode", 0) === 1
    property real autoSpeed: AppSettings.getFloat("Config_AutoSpeed", 3.0)

    // Tab Window Toggle State
    property bool isTabActive: false

    // Global Language (single source of truth)
    property int configLanguage: AppSettings.getInt("Config_Language", 0)

    // LLM Stats (mirrors Unity StatusPanelController)
    property string llmProvider: ""
    property string llmModel: ""
    property real   llmLatency: -1

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_ScreenMode" || key === "Config_Resolution") {
                applyScreenSettings();
            }
            if (key === "Config_Language") {
                mainWindow.configLanguage = AppSettings.getInt("Config_Language", 0);
            }
        }
    }

    // ─── Global UI scaling ───
    readonly property real uiScale: mainWindow.width / 1920.0

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
        sequence: "Alt+Return"
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

    TapHandler {
        id: rightClickMenuToggle
        target: null
        acceptedDevices: PointerDevice.Mouse
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (AppSettings.getInt("Config_RightClickMenu", 1) !== 1) return;
            if (menuPanel.isSubPanelOpen) return;
            mainWindow.isTabActive = !mainWindow.isTabActive;
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
        isTabActive: mainWindow.isTabActive
        menuPanelOpen: menuPanel.menuOpen
        backLog: mainBackLog
        configLanguage: mainWindow.configLanguage

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
        isLoggedIn: mainWindow.appState !== "login"
        configLanguage: mainWindow.configLanguage
        onCloseMenuRequested: mainWindow.isTabActive = false
        onLogoutRequested: {
            mainWindow.appState = "login";
            mainWindow.isTabActive = false;
        }
    }

    // ─── Global Eye Tracking ───
    // Use HoverHandler so gaze tracking keeps working across the whole window
    // (including while MenuPanel is open) without consuming click events.
    HoverHandler {
        id: globalGazeTracker
        target: null
        acceptedDevices: PointerDevice.Mouse
        onPointChanged: {
            if (AppSettings.getInt("Config_EyeTracking", 0) !== 1) return;
            if (!systemPanel.chatPanel) return;
            if (!systemPanel.chatPanel.live2DItem) return;
            var nx = ((point.position.x / mainWindow.width) - 0.5) * 2.0;
            var ny = ((point.position.y / mainWindow.height) - 0.5) * 2.0;
            systemPanel.chatPanel.setEyeTracking(
                Math.max(-0.7, Math.min(0.7, nx)),
                -Math.max(-0.7, Math.min(0.7, ny))
            );
        }
    }

    // Reset gaze to center when eye tracking is disabled
    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_EyeTracking") {
                if (AppSettings.getInt("Config_EyeTracking", 0) !== 1) {
                    if (systemPanel.chatPanel) {
                        systemPanel.chatPanel.resetEyeTracking();
                    }
                }
            }
        }
    }
}
