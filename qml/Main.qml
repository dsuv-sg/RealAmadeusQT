import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: root
    width:  1920
    height: 1080
    minimumWidth:  800
    minimumHeight: 450
    visible: true
    visibility: Window.FullScreen
    title: "Amadeus System"
    color: "#000000"

    // ─── State machine ───
    // "login" → "boot" → "chat"
    property string appState: "login"

    // Auto Mode (F3)
    property bool autoMode: AppSettings.getInt("Config_AutoMode", 0) === 1
    property real autoSpeed: AppSettings.getFloat("Config_AutoSpeed", 3.0)

    // Tab Window Toggle State
    property bool isTabActive: false

    function applyScreenSettings() {
        var screenMode = AppSettings.getInt("Config_ScreenMode", 0);
        var resIdx = AppSettings.getInt("Config_Resolution", 0);
        
        var w = 1920, h = 1080;
        if (resIdx === 0) { w = 1920; h = 1080; }
        else if (resIdx === 1) { w = 1600; h = 900; }
        else if (resIdx === 2) { w = 1280; h = 720; }

        if (screenMode === 0) {
            // FullScreen — use plain Qt.Window flag for true fullscreen
            root.flags = Qt.Window;
            root.minimumWidth = 0;
            root.maximumWidth = 16384;
            root.minimumHeight = 0;
            root.maximumHeight = 16384;
            root.visibility = Window.FullScreen;
        } else {
            // Windowed — disable resize/maximize via custom flags
            root.flags = Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint
                       | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint
                       | Qt.WindowCloseButtonHint;
            root.visibility = Window.Windowed;
            root.width = w;
            root.height = h;
            root.minimumWidth = w;
            root.maximumWidth = w;
            root.minimumHeight = h;
            root.maximumHeight = h;

            // Center on resolution change
            root.x = (Screen.width - w) / 2;
            root.y = (Screen.height - h) / 2;
        }
    }

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_ScreenMode" || key === "Config_Resolution") {
                applyScreenSettings();
            }
        }
    }

    // ─── Global UI scaling ───
    // All UI is designed for 1920×1080. When the window is smaller,
    // we scale the contentItem so proportions are preserved.
    readonly property real uiScale: root.width / 1920.0

    // Apply scale to the Window's implicit content container.
    // This does NOT conflict with child-level scale/x/y (e.g. SystemPanel Tab anim).
    Component.onCompleted: {
        contentItem.transform = [scaleXform];
        applyScreenSettings();
    }
    Scale {
        id: scaleXform
        xScale: root.uiScale
        yScale: root.uiScale
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
            root.autoMode = !root.autoMode;
            AppSettings.setInt("Config_AutoMode", root.autoMode ? 1 : 0);
            AppSettings.save();
        }
    }

    Shortcut {
        sequence: "Tab"
        onActivated: {
            if (menuPanel.isSubPanelOpen) return;
            root.isTabActive = !root.isTabActive
        }
    }

    // ─── System Panel ───
    SystemPanel {
        id: systemPanel
        width: 1920
        height: 1080
        enabled: !root.isTabActive

        appState: root.appState
        autoMode: root.autoMode
        autoSpeed: root.autoSpeed
        isTabActive: root.isTabActive

        onLoginAccepted: root.appState = "boot"
        onBootFinished: root.appState = "chat"
        onOpenMenuRequested: menuPanel.show()
        
        onSystemAnimProgressChanged: {
            if (root.isTabActive && systemAnimProgress >= 0.95 && !menuPanel.menuOpen) {
                menuPanel.show();
            } else if (!root.isTabActive && menuPanel.menuOpen) {
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
        onCloseMenuRequested: root.isTabActive = false
        onLogoutRequested: {
            root.appState = "login";
            root.isTabActive = false;
        }
    }
}
