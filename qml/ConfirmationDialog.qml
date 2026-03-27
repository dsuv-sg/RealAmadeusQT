import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// ConfirmationDialog - mirrors ConfirmationDialog.cs
/// Simple yes/no modal dialog.
Item {
    id: root
    signal confirmed()
    signal cancelled()
    signal closed()

    property string dialogMessage: ""
    property int    selectedIndex: 1 // 0: NO, 1: YES
    property int    configLanguage: AppSettings.getInt("Config_Language", 0)

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") {
                root.configLanguage = AppSettings.getInt("Config_Language", 0);
            }
        }
    }

    anchors.fill: parent

    // Darken background
    Rectangle {
        anchors.fill: parent
        color: "#1A1A1A"
        opacity: 0.7 * root.opacity
    }

    Rectangle {
        anchors.centerIn: parent
        width: 800
        height: 300
        color: "#1A1A1A"
        border.color: "#FFC900"
        border.width: 1

        ColumnLayout {

            width: parent.width
            height: parent.height

            Text {
                height: 80
                topPadding: -40
                anchors.centerIn: parent
                Layout.fillWidth: true
                text: root.dialogMessage
                color: "#FFFFFF"
                font { family: "MS Mincho"; pixelSize: 36 }
                verticalAlignment: Text.AlignTop
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // NO button (Left)
            Rectangle {
                width: 200; height: 60
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -200
                anchors.verticalCenterOffset: 100
                color: root.selectedIndex === 0 ? "#FFC900" : "#404040"
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: root.configLanguage === 1 ? "No" : "いいえ"
                    color: root.selectedIndex === 0 ? "#000000" : "#FFFFFF"
                    font { family: "MS Mincho"; pixelSize: 30; bold: true }
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = 0
                    onClicked: root.cancelled()
                }
            }

            // YES button (Right)
            Rectangle {
                width: 200; height: 60
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 200
                anchors.verticalCenterOffset: 100
                color: root.selectedIndex === 1 ? "#FFC900" : "#404040"
                radius: 2

                Text {
                    anchors.centerIn: parent
                    text: root.configLanguage === 1 ? "Yes" : "はい"
                    color: root.selectedIndex === 1 ? "#000000" : "#FFFFFF"
                    font { family: "MS Mincho"; pixelSize: 30; bold: true }
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = 1
                    onClicked: root.confirmed()
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { root.selectedIndex = 0; event.accepted = true; }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { root.selectedIndex = 1; event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedIndex === 1) root.confirmed();
            else root.cancelled();
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Backspace) { root.cancelled(); event.accepted = true; }
    }

    // ─── Fade and Focus ───
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 250 } }
    onVisibleChanged: {
        if (visible) {
            root.opacity = 0;
            root.selectedIndex = 1; // Default to YES
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
        interval: 250
        onTriggered: root.visible = false
    }
}
