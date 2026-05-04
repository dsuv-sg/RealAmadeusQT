import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T

Item {
    id: root
    width: 1920
    height: 1080
    signal closed()
    focus: true

    property int configLanguage: AppSettings.getInt("Config_Language", 0)

    FontLoader { id: notoKR; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKkr-Regular.otf" }

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

    function v12Text() {
        switch(configLanguage) {
        case 1: return "Added support for Chinese, Korean, Spanish, French, German, and Russian.\n" +
                       "Added eye tracking.\n" +
                       "Implemented desktop notification feature.\n" +
                       "Added lightweight mode.\n" +
                       "Implemented screen mode toggle with Alt+Enter and F11.\n" +
                       "Added Ollama and OpenRouter API providers.\n" +
                       "Fixed UI bugs.\n" +
                       "Improved security for API keys.\n" +
                       "Improved performance.";
        case 2: return "新增中文/韩语/西班牙语/法语/德语/俄语支持。\n" +
                       "新增视线追踪。\n" +
                       "实现了桌面通知功能。\n" +
                       "新增轻量模式。\n" +
                       "新增 Alt+Enter、F11 画面模式切换。\n" +
                       "添加了Ollama和OpenRouter的API提供者。\n" +
                       "修复UI错误。\n" +
                       "提高了API密钥等的安全性。\n" +
                       "改善性能。";
        case 3: return "중국어/한국어/스페인어/프랑스어/독일어/러시아어 지원 추가.\n" +
                       "시선 추적 추가.\n" +
                       "데스크톱 알림 기능을 구현했습니다.\n" +
                       "경량 모드 추가.\n" +
                       "Alt+Enter, F11 화면 모드 전환 추가.\n" +
                       "Ollama/OpenRouter API 제공자를 추가했습니다.\n" +
                       "UI 버그 수정.\n" +
                       "API 키 등의 보안을 강화했습니다.\n" +
                       "성능 개선.";
        case 4: return "Se agregó soporte para chino, coreano, español, francés, alemán y ruso.\n" +
                       "Se agregó seguimiento ocular.\n" +
                       "Se implementó la función de notificaciones de escritorio.\n" +
                       "Se agregó modo ligero.\n" +
                       "Se implementó cambio de modo de pantalla con Alt+Enter y F11.\n" +
                       "Se agregaron los proveedores de API Ollama y OpenRouter.\n" +
                       "Se corrigieron errores de UI.\n" +
                       "Se mejoró la seguridad de las claves API.\n" +
                       "Se mejoró el rendimiento.";
        case 5: return "Ajout du support chinois, coréen, espagnol, français, allemand et russe.\n" +
                       "Ajout du suivi du regard.\n" +
                       "Implémentation de la fonction de notifications de bureau.\n" +
                       "Ajout du mode léger.\n" +
                       "Ajout du changement de mode d'écran avec Alt+Entrée et F11.\n" +
                       "Ajout des fournisseurs d'API Ollama et OpenRouter.\n" +
                       "Correction de bugs UI.\n" +
                       "Amélioration de la sécurité pour les clés API.\n" +
                       "Amélioration des performances.";
        case 6: return "Unterstützung für Chinesisch, Koreanisch, Spanisch, Französisch, Deutsch und Russisch hinzugefügt.\n" +
                       "Blickverfolgung hinzugefügt.\n" +
                       "Desktop-Benachrichtigungsfunktion implementiert.\n" +
                       "Leichtmodus hinzugefügt.\n" +
                       "Bildschirmmodus-Umschaltung mit Alt+Enter und F11 hinzugefügt.\n" +
                       "Ollama/OpenRouter API-Anbieter hinzugefügt.\n" +
                       "UI-Fehler behoben.\n" +
                       "Sicherheit für API-Schlüssel verbessert.\n" +
                       "Leistung verbessert.";
        case 7: return "Добавлена поддержка китайского, корейского, испанского, французского, немецкого и русского.\n" +
                       "Добавлено отслеживание взгляда.\n" +
                       "Реализована функция уведомлений на рабочем столе.\n" +
                       "Добавлен облегчённый режим.\n" +
                       "Добавлено переключение режима экрана клавишами Alt+Enter и F11.\n" +
                       "Добавлены API-провайдеры Ollama и OpenRouter.\n" +
                       "Исправлены ошибки интерфейса.\n" +
                       "Улучшена безопасность для ключей API.\n" +
                       "Улучшена производительность.";
        default: return "中国語/韓国語/スペイン語/フランス語/ドイツ語/ロシア語 のサポートを追加しました。\n" +
                        "視線トラッキングを追加しました。\n" +
                        "デスクトップ通知機能を実装しました。\n" +
                        "軽量化モードを追加しました。\n" +
                        "Alt+Enter、F11 での画面モード切替を実装しました。\n" +
                        "APIプロバイダーにOllamaとOpenRouterを追加しました。\n" +
                        "UIのバグを修正しました。\n" +
                        "APIキーのセキュリティを向上させました。\n" +
                        "パフォーマンスを改善しました。";
        }
    }

    function v11Text() {
        switch(configLanguage) {
        case 1: return "Implemented click selection for the menu screen.\n" +
                       "Added language switching between Japanese and English.\n" +
                       "Added [Close/Cancel/Apply] buttons to various screens.\n" +
                       "Implemented scrollbars for ChangeLog and BackLog.\n" +
                       "Updated UI elements for better visibility.\n" +
                       "Started release of the lightweight version.";
        case 2: return "实现了菜单画面的点击选择。\n" +
                       "实现了日语/英语的语言切换。\n" +
                       "在各种画面上实现了[关闭/取消/应用]按钮。\n" +
                       "为ChangeLog/BackLog实现了滚动条。\n" +
                       "为提高可视性更改了部分UI。\n" +
                       "开始发布轻量版。";
        case 3: return "메뉴 화면의 클릭 선택을 구현했습니다.\n" +
                       "일본어/영어 언어 전환을 구현했습니다.\n" +
                       "각종 화면에 [닫기/취소/적용] 버튼을 구현했습니다.\n" +
                       "ChangeLog/BackLog용 스크롤바를 구현했습니다.\n" +
                       "가시성 향상을 위해 UI 일부를 변경했습니다.\n" +
                       "경량판 릴리스를 시작했습니다.";
        case 4: return "Se implementó la selección por clic en la pantalla de menú.\n" +
                       "Se agregó cambio de idioma entre japonés e inglés.\n" +
                       "Se agregaron botones [Cerrar/Cancelar/Aplicar] a varias pantallas.\n" +
                       "Se implementaron barras de desplazamiento para ChangeLog y BackLog.\n" +
                       "Se actualizaron elementos de UI para mejor visibilidad.\n" +
                       "Se inició el lanzamiento de la versión ligera.";
        case 5: return "Implémentation de la sélection par clic pour le menu.\n" +
                       "Ajout du changement de langue entre japonais et anglais.\n" +
                       "Ajout des boutons [Fermer/Annuler/Appliquer] à divers écrans.\n" +
                       "Implémentation des barres de défilement pour ChangeLog et BackLog.\n" +
                       "Mise à jour de l'UI pour une meilleure visibilité.\n" +
                       "Début de la publication de la version allégée.";
        case 6: return "Implementierung der Klickauswahl für den Menübildschirm.\n" +
                       "Sprachumschaltung zwischen Japanisch und Englisch hinzugefügt.\n" +
                       "[Schließen/Abbrechen/Anwenden]-Schaltflächen zu verschiedenen Bildschirmen hinzugefügt.\n" +
                       "Scrollbalken für ChangeLog und BackLog implementiert.\n" +
                       "UI-Elemente für bessere Sichtbarkeit aktualisiert.\n" +
                       "Veröffentlichung der leichten Version gestartet.";
        case 7: return "Реализован выбор в меню щелчком мыши.\n" +
                       "Добавлено переключение языка между японским и английским.\n" +
                       "Добавлены кнопки [Закрыть/Отмена/Применить] на различные экраны.\n" +
                       "Реализованы полосы прокрутки для ChangeLog и BackLog.\n" +
                       "Обновлены элементы интерфейса для лучшей видимости.\n" +
                       "Начат выпуск облегчённой версии.";
        default: return "メニュー画面のクリック選択を実装しました。\n" +
                        "日本語/英語の言語切り替えを実装しました。\n" +
                        "各種画面に[閉じる/キャンセル/適用]ボタンを実装しました。\n" +
                        "チェンジログ/バックログ用に、スクロールバーを実装しました。\n" +
                        "視認性の向上のため、UIの一部を変更しました。\n" +
                        "軽量化版のリリースを開始しました。";
        }
    }

    function v101Text() {
        switch(configLanguage) {
        case 1: return "Fixed an issue where GPU usage was abnormally high.\n" +
                       "Fixed a window scaling issue when minimizing in fullscreen.\n" +
                       "Fixed an issue where re-logging in after logout was impossible.\n" +
                       "Fixed a bug where emotion tags were appearing for some AI services.";
        case 2: return "修复了GPU使用率异常高的问题。\n" +
                       "修复了全屏状态下最小化时窗口异常变小的问题。\n" +
                       "修复了登出后无法重新登录的问题。\n" +
                       "修复了使用部分AI服务时情感标签显示的问题。";
        case 3: return "GPU 사용률이 비정상적으로 높아지는 문제를 수정했습니다.\n" +
                       "전체 화면 상태에서 최소화 시 창이 비정상적으로 작아지는 문제를 수정했습니다.\n" +
                       "로그아웃 후 재로그인이 불가능해지는 문제를 수정했습니다.\n" +
                       "일부 AI 서비스 이용 시 감정 태그가 표시되는 문제를 수정했습니다.";
        case 4: return "Se corrigió un problema de uso anormalmente alto de GPU.\n" +
                       "Se corrigió un problema de escala de ventana al minimizar en pantalla completa.\n" +
                       "Se corrigió un problema donde re-iniciar sesión tras cerrarla era imposible.\n" +
                       "Se corrigió un error donde aparecían etiquetas de emoción en algunos servicios de AI.";
        case 5: return "Correction d'un problème d'utilisation anormalement élevée du GPU.\n" +
                       "Correction d'un problème de mise à l'échelle lors de la minimisation en plein écran.\n" +
                       "Correction d'un problème empêchant la reconnexion après déconnexion.\n" +
                       "Correction d'un bug faisant apparaître des tags d'émotion pour certains services AI.";
        case 6: return "Problem mit abnormal hoher GPU-Auslastung behoben.\n" +
                       "Problem mit der Fensterskalierung bei Minimierung im Vollbild behoben.\n" +
                       "Problem behoben, bei dem eine erneute Anmeldung nach der Abmeldung unmöglich war.\n" +
                       "Fehler behoben, bei dem Emotionstags bei einigen KI-Diensten angezeigt wurden.";
        case 7: return "Исправлена проблема с аномально высоким использованием GPU.\n" +
                       "Исправлена проблема с масштабированием окна при сворачивании в полноэкранном режиме.\n" +
                       "Исправлена проблема, при которой повторный вход после выхода был невозможен.\n" +
                       "Исправлена ошибка, при которой теги эмоций отображались для некоторых AI-сервисов.";
        default: return "GPU使用率が異常に高くなってしまう問題を修正しました。\n" +
                        "フルスクリーン状態での最小化時に、ウィンドウが異常に小さくなってしまう問題を修正しました。\n" +
                        "ログアウト後の再ログインが不可能になってしまう問題を修正しました。\n" +
                        "一部AIサービスの利用時にて、感情タグが表示されてしまう問題を修正しました。";
        }
    }

    function v10Text() {
        switch(configLanguage) {
        case 1: return "Released the first version of Real Amadeus.\n" +
                       "Includes basic conversation features.";
        case 2: return "发布了Real Amadeus的最初版本。\n" +
                       "仅具备基本的对话功能。";
        case 3: return "Real Amadeus의 최초 버전을 릴리스했습니다.\n" +
                       "기본적인 대화 기능만을 갖추고 있습니다.";
        case 4: return "Se lanzó la primera versión de Real Amadeus.\n" +
                       "Incluye funciones básicas de conversación.";
        case 5: return "Sortie de la première version de Real Amadeus.\n" +
                       "Comprend les fonctionnalités de conversation de base.";
        case 6: return "Erste Version von Real Amadeus veröffentlicht.\n" +
                       "Enthält nur grundlegende Konversationsfunktionen.";
        case 7: return "Выпущена первая версия Real Amadeus.\n" +
                       "Включает только базовые функции разговора.";
        default: return "リアルアマデウスの最初のバージョンをリリースしました。\n" +
                        "基本的な会話機能のみを備えています。";
        }
    }

    // ─── Mixed-font HTML generator (per-character script detection) ───
    // Hangul → Noto Serif, Cyrillic → MS Mincho + letterSpacing -6.4, Other → MS Mincho
    function mixedTextHtml(text, pixelSize) {
        if (!text) return "";

        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;")
                      .replace(/\n/g, "<br>");
        }

        function charType(c) {
            var code = c.charCodeAt(0);
            if (code >= 0xAC00 && code <= 0xD7AF) return "hangul";
            if (code >= 0x1100 && code <= 0x11FF) return "hangul";
            if (code >= 0x3130 && code <= 0x318F) return "hangul";
            if (code >= 0x0400 && code <= 0x04FF) return "cyrillic";
            return "other";
        }

        var html = "";
        var currentType = "";
        var currentText = "";

        function flush() {
            if (currentText.length === 0) return;
            if (currentType === "hangul") {
                var family = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";
                html += '<span style="font-family: \'' + family + '\';">' + escapeHtml(currentText) + '</span>';
            } else if (currentType === "cyrillic") {
                html += '<span style="font-family: \'MS Mincho\'; letter-spacing: -8.4px;">' + escapeHtml(currentText) + '</span>';
            } else {
                html += '<span style="font-family: \'MS Mincho\';">' + escapeHtml(currentText) + '</span>';
            }
            currentText = "";
        }

        for (var i = 0; i < text.length; i++) {
            var c = text[i];
            var type = charType(c);
            if (type !== currentType && currentText.length > 0) {
                flush();
            }
            if (currentText.length === 0) currentType = type;
            currentText += c;
        }
        flush();

        return '<span style="font-size: ' + pixelSize + 'px;">' + html + '</span>';
    }

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") { configLanguage = AppSettings.getInt("Config_Language", 0); }
        }
    }

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
                color: "#FFFFFF"
            }
            contentItem: Rectangle {
                implicitWidth: 10
                color: "#FF9900"
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

                // Version 1.2
                Column {
                    width: logScroll.width
                    Item {
                        width: logScroll.width
                        height: 50

                        Text {
                            y: 4
                            text: "Version 1. 2"
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
                            text: "2026. 05. 04"
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
                        text: mixedTextHtml(v12Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
                        font.pixelSize: 28
                        wrapMode: Text.Wrap
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 42
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignTop

                    }
                }

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
                        text: mixedTextHtml(v11Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
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
                        text: mixedTextHtml(v101Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
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
                        text: mixedTextHtml(v10Text(), font.pixelSize)
                        color: "#FFFFFF"
                        textFormat: Text.RichText
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
            text: mixedTextHtml(t("閉じる", "Close", "关闭", "닫기", "Cerrar", "Fermer", "Schließen", "Закрыть"), font.pixelSize)
            color: "#FFFFFF"
            textFormat: Text.RichText
            font.pixelSize: 32
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
