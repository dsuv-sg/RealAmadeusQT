import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: loginPanel
    signal loginAccepted()

    // ─── Design constants from Unity MCP data ───────────────────────
    // Canvas reference: 1920×1080
    // All Unity units map 1:1 to these reference pixels.
    readonly property real refW: 1920
    readonly property real refH: 1080
    readonly property real scaleX: width  / refW
    readonly property real scaleY: height / refH
    readonly property real sc:    Math.min(scaleX, scaleY)

    FontLoader {
        id: mateFont
        source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/MateSC-Regular.ttf"
    }


    // ─── Logo ────────────────────────────────────────────────────────
    // Unity (canvas 1920×1080): anchorMin=(0.5,1.0) = top-center anchor
    // anchoredPosition=(0,-340) → logo center is 340px BELOW the top edge
    // size=700×700 → top of logo = 340-350 = -10px above panel top (slightly clipped)
    // In QML: center of logo = 340*sc from panel top → y = (340-350)*sc = -10*sc
    Image {
        id: logoImage
        width:  700 * sc
        height: 700 * sc
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -182 * sc
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/amadeus_logo_v3.png"
        fillMode: Image.PreserveAspectFit
    }

    // ─── Login Form container (LoginForm node) ───────────────────────
    // Unity: center anchor, anchoredPosition=(0,-114), in canvas space
    // Center of form from panel center: (0, -114) = 114 below center
    // Panel center in panel coords = (panel.width/2, panel.height/2)
    // Form center Y in panel = panel.height/2 + 114*sc
    // ─── USER ID Row ───────────────────────────────────────────
    // UserID_Group: VerticalLayout top item, height=100, Y offset=0
    Item {
        id: userIdGroup
        width:  parent.width
        height: 50 * sc
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenterOffset: 131.5 * sc

        // Label: size=220×50, anchoredPosition=(-429,0) from group center
        // Group center X = parent.width/2
        // Label center X = parent.width/2 - 429*sc
        Text {
            id: userIdLabel
            text: "USER ID"
            font.family: mateFont.status === FontLoader.Ready ? mateFont.name : "sans-serif"
            font.pixelSize: 29 * sc
            font.bold: true
            color: "#FFE600"
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter

            width: 220 * sc
            height: 50 * sc
            anchors.verticalCenter: parent.verticalCenter
            // center of label = parent.width/2 - 429*sc
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -429 * sc
        }

        // Input: size=600×50, center of group, color=black
        Rectangle {
            id: userIdInputBg
            width: 600 * sc
            height: 50 * sc
            anchors.centerIn: parent
            color: "#000000"
            border.color: Qt.rgba(0.566, 0.566, 0.566, 0.5)
            border.width: 1

            TextInput {
                id: idInput
                anchors.fill: parent
                anchors.leftMargin: 10 * sc
                anchors.rightMargin: 10 * sc
                anchors.topMargin: 5 * sc
                anchors.bottomMargin: 5 * sc
                color: "#FFD700"
                font.family: "MS Mincho"
                font.pixelSize: 36 * sc
                verticalAlignment: TextInput.AlignVCenter
                clip: true

                Keys.onReturnPressed: attemptLogin()
                Keys.onEnterPressed:  attemptLogin()
            }
        }
    }

    // ─── PASSWORD Row ─────────────────────────────────────────
    // Unity VerticalLayout spacing=-30, each group height=100
    // Password top = UserID top + 100 - 30 = UserID top + 70
    Item {
        id: passwordGroup
        width: parent.width
        height: 50 * sc
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenterOffset: 201.5 * sc

        Text {
            id: passwordLabel
            text: "PASSWORD"
            font.family: mateFont.status === FontLoader.Ready ? mateFont.name : "sans-serif"
            font.pixelSize: 29 * sc
            font.bold: true
            color: "#FFD700"
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter

            width: 220 * sc
            height: 50 * sc
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -429 * sc
        }

        Rectangle {
            id: passwordInputBg
            width: 600 * sc
            height: 50 * sc
            anchors.centerIn: parent
            color: "#000000"
            border.color: Qt.rgba(0.566, 0.566, 0.566, 0.5)
            border.width: 1

            TextInput {
                id: pwInput
                anchors.fill: parent
                anchors.leftMargin: 10 * sc
                anchors.rightMargin: 10 * sc
                anchors.topMargin: 5 * sc
                anchors.bottomMargin: 5 * sc
                color: "#FFD700"
                font.family: "MS Mincho"
                font.pixelSize: 36 * sc
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "*"
                clip: true

                Keys.onReturnPressed: attemptLogin()
                Keys.onEnterPressed:  attemptLogin()
            }
        }
    }

    // ─── Login Button ────────────────────────────────────────────────
    // Unity: Login_Button parent=LoginPanel, anchoredPosition=(334,-184), size=65×65
    // anchoredPosition is relative to LoginPanel center
    // QML: x = parentW/2 + 334*sc, y = parentH/2 + 184*sc (positive down)
    Image {
        id: loginButton
        width:  65 * sc
        height: 65 * sc
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/amadeus_login_button_v2.png"
        fillMode: Image.PreserveAspectFit

        // center of button = (width/2 + 334*sc, height/2 + 184*sc) from panel center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter:   parent.verticalCenter
        anchors.horizontalCenterOffset: 334 * sc
        anchors.verticalCenterOffset:   201.5 * sc

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: attemptLogin()
        }
    }

    // ─── Error message ───────────────────────────────────────────────
    Text {
        id: errorText
        visible: false
        text: "ACCESS DENIED"
        color: "#FF0000"
        font.family: mateFont.status === FontLoader.Ready ? mateFont.name : "sans-serif"
        font.pixelSize: 20 * sc
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenterOffset: 271.5 * sc
        anchors.horizontalCenterOffset: -220 * sc
    }

    // ─── Login logic ─────────────────────────────────────────────────
    function attemptLogin() {
        var validNames = ["Salieri"]
        var validPasswords = ["MakiseKurisu"]

        if (idInput.text.length > 0 &&
            pwInput.text.length > 0 &&
            (validNames.indexOf(idInput.text) >= 0 ||
             validPasswords.indexOf(pwInput.text) >= 0)) {
            errorText.visible = false
            MemoryManager.setUserName("Salieri")
            loginAccepted()
        } else if (idInput.text.length === 0 || pwInput.text.length === 0) {
            errorText.text = "ID AND PASSWORD REQUIRED"
            errorText.visible = true
        } else {
            errorText.text = "ACCESS DENIED"
            errorText.visible = true
        }
    }

    // Focus form on appear
    Component.onCompleted: {
        idInput.forceActiveFocus()
    }
}
