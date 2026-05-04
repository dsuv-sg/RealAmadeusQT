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
    property int    selectedIndex: 0 // 0: YES, 1: NO

    anchors.fill: parent

    // Darken background
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7 * root.opacity
    }

    Rectangle {
        anchors.centerIn: parent
        width: 500
        height: 220
        color: "#050d18"
        border.color: "#FF9900"
        border.width: 1
        radius: 2

        ColumnLayout {
            anchors { fill: parent; margins: 30 }
            spacing: 25

            Text {
                Layout.fillWidth: true
                text: root.dialogMessage
                color: "#FFFFFF"
                font { family: "MS Mincho"; pixelSize: 26 }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 40

                // YES button
                Rectangle {
                    width: 160; height: 50
                    color: root.selectedIndex === 0 ? "#FF9900" : "#222222"
                    border.color: "#FFFFFF"; border.width: root.selectedIndex === 0 ? 2 : 1
                    Text {
                        anchors.centerIn: parent
                        text: "YES"
                        color: "#FFFFFF"
                        font { family: "MS Mincho"; pixelSize: 24; bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selectedIndex = 0
                        onClicked: root.confirmed()
                    }
                }

                // NO button
                Rectangle {
                    width: 160; height: 50
                    color: root.selectedIndex === 1 ? "#FF9900" : "#222222"
                    border.color: "#FFFFFF"; border.width: root.selectedIndex === 1 ? 2 : 1
                    Text {
                        anchors.centerIn: parent
                        text: "NO"
                        color: "#FFFFFF"
                        font { family: "MS Mincho"; pixelSize: 24; bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selectedIndex = 1
                        onClicked: root.cancelled()
                    }
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { root.selectedIndex = 0; event.accepted = true; }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { root.selectedIndex = 1; event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedIndex === 0) root.confirmed();
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
            root.selectedIndex = 1; // Default to NO for safety
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
