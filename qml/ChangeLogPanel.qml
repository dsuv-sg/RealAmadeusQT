import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T

Item {
    id: root
    width: 1920
    height: 1080
    signal closed()
    focus: true

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
                color: "#FF9900"
            }
            contentItem: Rectangle {
                implicitWidth: 10
                color: "#FFFFFF"
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
                        text: "メニュー画面のクリック選択を実装しました。\n" +
                              "日本語/英語の言語切り替えを実装しました。\n" +
                              "各種画面に[閉じる/キャンセル/適用]ボタンを実装しました。\n" +
                              "チェンジログ/バックログ用に、スクロールバーを実装しました。\n" +
                              "視認性の向上のため、UIの一部を変更しました。\n" +
                              "軽量化版のリリースを開始しました。"
                        color: "#FFFFFF"
                        font.family: "MS Mincho"
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
                        text: "GPU使用率が異常に高くなってしまう問題を修正しました。\n" +
                              "フルスクリーン状態での最小化時に、ウィンドウが異常に小さくなってしまう問題を修正しました。\n" +
                              "ログアウト後の再ログインが不可能になってしまう問題を修正しました。\n" +
                              "一部AIサービスの利用時にて、感情タグが表示されてしまう問題を修正しました。"
                        color: "#FFFFFF"
                        font.family: "MS Mincho"
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
                        text: "リアルアマデウスの最初のバージョンをリリースしました。\n" +
                              "基本的な会話機能のみを備えています。"
                        color: "#FFFFFF"
                        font.family: "MS Mincho"
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
