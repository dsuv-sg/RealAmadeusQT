import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

/// ConfigPanel - mirrors ConfigPanelController.cs
/// 5 categories: 基本設定(0) テキスト(1) サウンド(2) グラフィック(3) API(4)
Item {
    id: root
    signal closed()
    focus: true

    property int activeCategory: 0
    property int currentProviderIndex: AppSettings.getInt("Config_ApiProvider", 0)

    // Per-provider key/model buffers ( mirrors ConfigPanelController's apiKeys dict )
    property var apiKeyBuffer:   ({})
    property var modelNameBuffer: ({})

    // External language binding (from Main.qml / MenuPanel)
    property int configLanguage: AppSettings.getInt("Config_Language", 0)
    onConfigLanguageChanged: {
        root.lang = configLanguage;
    }

    property int lang: AppSettings.getInt("Config_Language", 0)
    property int originalLang: 0
    property bool suppressLanguageCommit: true

    readonly property string _fontFamily: {
        if (lang === 3 && notoKR.status === FontLoader.Ready) return notoKR.name;
        return "MS Mincho";
    }

    // Hybrid font rendering
    // Korean: Hangul → Noto Serif, other → MS Mincho
    // Russian: Cyrillic → MS Mincho + letter-spacing -8.4, other → MS Mincho
    function styledText(text) {
        if (!text) return "";

        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;");
        }

        function isHangul(c) {
            var code = c.charCodeAt(0);
            return (code >= 0xAC00 && code <= 0xD7AF) ||
                   (code >= 0x1100 && code <= 0x11FF) ||
                   (code >= 0x3130 && code <= 0x318F);
        }

        function isCyrillic(c) {
            var code = c.charCodeAt(0);
            return (code >= 0x0400 && code <= 0x04FF);
        }

        var result = "";
        var hangulRun = "";
        var cyrillicRun = "";
        var otherRun = "";
        var krFace = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";

        function flushHangul() {
            if (hangulRun.length === 0) return;
            result += '<font face="' + krFace + '">' + escapeHtml(hangulRun) + '</font>';
            hangulRun = "";
        }
        function flushCyrillic() {
            if (cyrillicRun.length === 0) return;
            result += '<span style="letter-spacing: -8.4px;">' + escapeHtml(cyrillicRun) + '</span>';
            cyrillicRun = "";
        }
        function flushOther() {
            if (otherRun.length === 0) return;
            result += '<font face="MS Mincho">' + escapeHtml(otherRun) + '</font>';
            otherRun = "";
        }

        for (var i = 0; i < text.length; i++) {
            var c = text[i];
            if (lang === 3 && isHangul(c)) {
                flushCyrillic();
                flushOther();
                hangulRun += c;
            } else if (lang === 7 && isCyrillic(c)) {
                flushHangul();
                flushOther();
                cyrillicRun += c;
            } else {
                flushHangul();
                flushCyrillic();
                otherRun += c;
            }
        }
        flushHangul();
        flushCyrillic();
        flushOther();

        return result;
    }

    // Language-name styling: always render Hangul in Noto Serif regardless of current lang
    function styledLanguageName(text) {
        if (!text) return "";
        function escapeHtml(str) {
            return str.replace(/&/g, "&amp;")
                      .replace(/</g, "&lt;")
                      .replace(/>/g, "&gt;");
        }
        function isHangul(c) {
            var code = c.charCodeAt(0);
            return (code >= 0xAC00 && code <= 0xD7AF) ||
                   (code >= 0x1100 && code <= 0x11FF) ||
                   (code >= 0x3130 && code <= 0x318F);
        }
        var result = "";
        var hangulRun = "";
        var otherRun = "";
        var krFace = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";
        function flushHangul() {
            if (hangulRun.length === 0) return;
            result += '<font face="' + krFace + '">' + escapeHtml(hangulRun) + '</font>';
            hangulRun = "";
        }
        function flushOther() {
            if (otherRun.length === 0) return;
            result += '<font face="MS Mincho">' + escapeHtml(otherRun) + '</font>';
            otherRun = "";
        }
        for (var i = 0; i < text.length; i++) {
            var c = text[i];
            if (isHangul(c)) {
                flushOther();
                hangulRun += c;
            } else {
                flushHangul();
                otherRun += c;
            }
        }
        flushHangul();
        flushOther();
        return result;
    }

    // Mutable language-dependent arrays (rebuilt on lang change)
    property var categoryNames: [
        t("システム", "System", "系统", "시스템", "Sistema", "Système", "System", "Система"),
        t("テキスト", "Text", "文本", "텍스트", "Texto", "Texte", "Text", "Текст"),
        t("サウンド", "Sound", "音频", "사운드", "Sonido", "Son", "Sound", "Звук"),
        t("グラフィック", "Graphics", "图像", "그래픽", "Gráficos", "Graphismes", "Grafik", "Графика"),
        t("API", "API", "API", "API", "API", "API", "API", "API")
    ]
    property var screenModeModel: [
        t("フルスクリーン", "Fullscreen", "全屏", "전체 화면", "Pantalla completa", "Plein écran", "Vollbild", "Полный экран"),
        t("ウィンドウ", "Windowed", "窗口模式", "창 모드", "Modo ventana", "Mode fenêtré", "Fenstermodus", "Оконный режим")
    ]

    function rebuildLocalizedArrays() {
        categoryNames = [
            t("システム", "System", "系统", "시스템", "Sistema", "Système", "System", "Система"),
            t("テキスト", "Text", "文本", "텍스트", "Texto", "Texte", "Text", "Текст"),
            t("サウンド", "Sound", "音频", "사운드", "Sonido", "Son", "Sound", "Звук"),
            t("グラフィック", "Graphics", "图像", "그래픽", "Gráficos", "Graphismes", "Grafik", "Графика"),
            t("API", "API", "API", "API", "API", "API", "API", "API")
        ];
        screenModeModel = [
            t("フルスクリーン", "Fullscreen", "全屏", "전체 화면", "Pantalla completa", "Plein écran", "Vollbild", "Полный экран"),
            t("ウィンドウ", "Windowed", "窗口模式", "창 모드", "Modo ventana", "Mode fenêtré", "Fenstermodus", "Оконный режим")
        ];
    }

    onLangChanged: {
        rebuildLocalizedArrays();
        if (visible) {
            // Force Repeater delegate recreation by temporarily clearing model
            sidebarRepeater.model = null;
            sidebarRepeater.model = root.categoryNames;
        }
    }

    FontLoader { id: notoKR; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(ja, en, zh, ko, es, fr, de, ru) {
        switch(lang) {
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

    readonly property var providerNames: ["OpenAI", "Google Gemini", "Anthropic Claude", "Groq", "Vertex AI", "Ollama", "OpenRouter"]

    readonly property var languageNames: [
        "日本語",
        "English",
        "中文",
        "한국어",
        "Español",
        "Français",
        "Deutsch",
        "Русский"
    ]

    Component.onCompleted: {
        root.suppressLanguageCommit = true;
        loadSettings();
        root.suppressLanguageCommit = false;
    }

    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_Language") {
                var newLang = AppSettings.getInt("Config_Language", 0);
                root.lang = newLang;
                if (languageCombo.currentIndex !== newLang) {
                    root.suppressLanguageCommit = true;
                    languageCombo.currentIndex = newLang;
                    root.suppressLanguageCommit = false;
                }
            }
        }
    }

    function loadSettings() {
        root.suppressLanguageCommit = true;
        root.lang = AppSettings.getInt("Config_Language", 0);
        root.originalLang = root.lang;
        rebuildLocalizedArrays();
        currentProviderIndex = AppSettings.getInt("Config_ApiProvider", 0);

        for (var i = 0; i < providerNames.length; i++) {
            var k = AppSettings.getString("Config_ApiKey_" + i, "");
            if (k === "" && i === currentProviderIndex)
                k = AppSettings.getString("Config_ApiKey", "");
            apiKeyBuffer[i] = k;

            var m = AppSettings.getString("Config_ModelName_" + i, "");
            if (m === "" && i === currentProviderIndex)
                m = AppSettings.getString("Config_ModelName", "");
            modelNameBuffer[i] = m;
        }
        apiKeyField.text   = apiKeyBuffer[currentProviderIndex] || "";
        modelNameField.text = modelNameBuffer[currentProviderIndex] || "";

        skipLoadingToggle.checked  = AppSettings.getInt("Config_SkipLoading", 0) === 1;
        rightClickToggle.checked   = AppSettings.getInt("Config_RightClickMenu", 1) === 1;
        eyeTrackingToggle.checked  = AppSettings.getInt("Config_EyeTracking", 0) === 1;
        notificationsToggle.checked = AppSettings.getInt("Config_DesktopNotifications", 1) === 1;
        lightweightToggle.checked  = AppSettings.getInt("Config_LightweightMode", 0) === 1;
        languageCombo.currentIndex = Math.min(root.lang, languageNames.length - 1);
        textSpeedRow.sliderValue   = AppSettings.getFloat("Config_TextSpeed", 1.0);
        autoSpeedRow.sliderValue   = AppSettings.getFloat("Config_AutoSpeed", 3.0);
        autoModeToggle.checked     = AppSettings.getInt("Config_AutoMode", 0) === 1;
        masterVolRow.sliderValue   = AppSettings.getFloat("Config_MasterVol", 1.0);
        bgmVolRow.sliderValue      = AppSettings.getFloat("Config_BGMVol", 0.8);
        seVolRow.sliderValue       = AppSettings.getFloat("Config_SEVol", 1.0);
        voiceVolRow.sliderValue    = AppSettings.getFloat("Config_VoiceVol", 1.0);
        screenModeCombo.currentIndex = AppSettings.getInt("Config_ScreenMode", 0);
        resolutionCombo.currentIndex = AppSettings.getInt("Config_Resolution", 0);
        webSearchToggle.checked    = AppSettings.getInt("Config_WebSearch", 0) === 1;
        providerCombo.currentIndex = currentProviderIndex;
        vertexProjectField.text    = AppSettings.getString("Config_VertexProject", "");
        vertexLocationField.text   = AppSettings.getString("Config_VertexLocation", "us-central1");
        ollamaHostField.text       = AppSettings.getString("Config_OllamaHost", "http://localhost:11434");
        root.suppressLanguageCommit = false;
    }

    function saveSettings() {
        apiKeyBuffer[currentProviderIndex]   = apiKeyField.text;
        modelNameBuffer[currentProviderIndex] = modelNameField.text;

        var newLang = languageCombo.currentIndex;
        AppSettings.setInt("Config_Language", newLang);
        root.lang = newLang;

        AppSettings.setInt("Config_SkipLoading",       skipLoadingToggle.checked ? 1 : 0);
        AppSettings.setInt("Config_RightClickMenu",    rightClickToggle.checked  ? 1 : 0);
        AppSettings.setInt("Config_EyeTracking",       eyeTrackingToggle.checked ? 1 : 0);
        AppSettings.setInt("Config_DesktopNotifications", notificationsToggle.checked ? 1 : 0);
        AppSettings.setInt("Config_LightweightMode",   lightweightToggle.checked ? 1 : 0);
        AppSettings.setFloat("Config_TextSpeed",       textSpeedRow.sliderValue);
        AppSettings.setFloat("Config_AutoSpeed",       autoSpeedRow.sliderValue);
        AppSettings.setInt("Config_AutoMode",          autoModeToggle.checked  ? 1 : 0);
        AppSettings.setFloat("Config_MasterVol",       masterVolRow.sliderValue);
        AppSettings.setFloat("Config_BGMVol",          bgmVolRow.sliderValue);
        AppSettings.setFloat("Config_SEVol",           seVolRow.sliderValue);
        AppSettings.setFloat("Config_VoiceVol",        voiceVolRow.sliderValue);
        AppSettings.setInt("Config_ScreenMode",        screenModeCombo.currentIndex);
        AppSettings.setInt("Config_Resolution",        resolutionCombo.currentIndex);
        AppSettings.setInt("Config_ApiProvider",       providerCombo.currentIndex);
        AppSettings.setInt("Config_WebSearch",         webSearchToggle.checked  ? 1 : 0);
        AppSettings.setString("Config_VertexProject",  vertexProjectField.text);
        AppSettings.setString("Config_VertexLocation", vertexLocationField.text);
        AppSettings.setString("Config_OllamaHost",     ollamaHostField.text || "http://localhost:11434");

        for (var i = 0; i < providerNames.length; i++) {
            AppSettings.setString("Config_ApiKey_"   + i, apiKeyBuffer[i] || "");
            AppSettings.setString("Config_ModelName_" + i, modelNameBuffer[i] || "");
        }
        AppSettings.setString("Config_ApiKey",   apiKeyBuffer[currentProviderIndex] || "");
        AppSettings.setString("Config_ModelName", modelNameBuffer[currentProviderIndex] || "");
        AppSettings.save();
    }

    function onProviderChanged(newIdx) {
        apiKeyBuffer[currentProviderIndex]   = apiKeyField.text;
        modelNameBuffer[currentProviderIndex] = modelNameField.text;
        currentProviderIndex = newIdx;
        apiKeyField.text    = apiKeyBuffer[newIdx] || "";
        modelNameField.text = modelNameBuffer[newIdx] || "";
    }

    // ─── Background ───
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    // ─── Main Content Wrapper ───
    Item {
        id: mainWrapper
        anchors.fill: parent

        // Main CONFIG Label
        Text {
            id: configTitle
            anchors { top: parent.top; left: parent.left; topMargin: 55; leftMargin: 22 }
            width: 400
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "CONFIG"
            color: "#FF9900"
            font { family: "MS Mincho"; pixelSize: 90 }
        }

        // Sidebar area
        Column {
            id: sidebarCol
            anchors { left: parent.left; top: parent.top; topMargin: 200; leftMargin: 20 }
            spacing: 15

            Repeater {
                id: sidebarRepeater
                model: root.categoryNames
                delegate: Rectangle {
                    width: 400; height: 100
                    color: "#333333"
                    Text {
                        anchors.centerIn: parent
                        text: styledText(modelData)
                        textFormat: Text.RichText
                        color: "#FF9900"
                        font { family: root._fontFamily; pixelSize: 36 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.activeCategory = index }
                    border.color: index === root.activeCategory ? "#ffffff" : "transparent"
                    border.width: 2
                }
            }
        }

        // ─── Content Area ───
        Item {
            id: contentArea
            anchors { left: parent.left; leftMargin: 430; top: parent.top; topMargin: 40; right: parent.right; rightMargin: 210; bottom: parent.bottom }

            ColumnLayout {
                anchors.fill: parent
                spacing: 20

                // Category Header
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    Text {
                        id: categoryHeaderText
                        anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
                        text: styledText(root.categoryNames[root.activeCategory])
                        textFormat: Text.RichText
                        color: "#FF9900"
                        font { family: root._fontFamily; pixelSize: 48 }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 2
                    Layout.leftMargin: 40
                    Layout.rightMargin: 40
                    Layout.fillWidth: true
                    color: "#FF9900"
                }

                // Category Pages (Unity: VerticalLayoutGroup spacing=15)
                Item {
                    id: pagesContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // ── 基本設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 0
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigRow { label: t("表示言語", "Display Language", "显示语言", "표시 언어", "Idioma", "Langue", "Sprache", "Язык"); ConfigComboBox {
                            id: languageCombo; model: root.languageNames;
                            contentItem: Text {
                                id: langComboText
                                leftPadding: 12
                                text: styledLanguageName(root.languageNames[languageCombo.currentIndex] || "")
                                textFormat: Text.RichText
                                color: "#FFFFFF"
                                font { family: root._fontFamily; pixelSize: 24 }
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                Connections {
                                    target: languageCombo
                                    function onCurrentIndexChanged() {
                                        langComboText.text = styledLanguageName(root.languageNames[languageCombo.currentIndex] || "");
                                    }
                                }
                            }
                            delegate: ItemDelegate {
                                width: languageCombo.width; height: 50
                                background: Rectangle { color: highlighted ? "#111111" : "#1A1A1A" }
                                contentItem: Text {
                                    text: styledLanguageName(modelData)
                                    textFormat: Text.RichText
                                    color: "#FFFFFF"
                                    font { family: root._fontFamily; pixelSize: 24 }
                                    verticalAlignment: Text.AlignVCenter; leftPadding: 12
                                }
                                highlighted: languageCombo.highlightedIndex === index
                            }
                            onCurrentIndexChanged: {
                                if (root.suppressLanguageCommit || !root.visible || currentIndex === -1) return;
                                if (currentIndex !== AppSettings.getInt("Config_Language", 0)) {
                                    AppSettings.setInt("Config_Language", currentIndex);
                                    AppSettings.save();
                                }
                            }
                        } }
                        ConfigRow { label: t("起動画面スキップ", "Skip Loading Screen", "跳过启动画面", "로딩 화면 스킵", "Saltar pantalla de carga", "Passer l'écran de chargement", "Ladebildschirm überspringen", "Пропускать экран загрузки"); ConfigCheckBox { id: skipLoadingToggle } }
                        ConfigRow { label: t("右クリックメニュー", "Right Click Menu", "右键菜单", "우클릭 메뉴", "Menú clic derecho", "Menu clic droit", "Rechtsklick-Menü", "Меню правой кнопки мыши"); ConfigCheckBox { id: rightClickToggle } }
                        ConfigRow { label: t("視線トラッキング", "Eye Tracking", "视线追踪", "시선 추적", "Seguimiento de ojos", "Suivi oculaire", "Blick-Tracking", "Трекинг взгляда"); ConfigCheckBox { id: eyeTrackingToggle } }
                        ConfigRow { label: t("通知を表示", "Show Notifications", "显示通知", "알림 표시", "Mostrar notificaciones", "Afficher les notifications", "Benachrichtigungen anzeigen", "Показывать уведомления"); ConfigCheckBox { id: notificationsToggle } }
                        ConfigRow { label: t("軽量化モード", "Lightweight Mode", "轻量模式", "경량 모드", "Modo ligero", "Mode léger", "Leichtmodus", "Легкий режим"); ConfigCheckBox { id: lightweightToggle } }
                        Item { Layout.fillHeight: true }
                    }

                    // ── テキスト設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 1
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigSliderRow { id: textSpeedRow;  label: t("文字表示速度", "Text Speed", "文字速度", "텍스트 속도", "Velocidad de texto", "Vitesse du texte", "Textgeschwindigkeit", "Скорость текста"); sliderFrom: 0.1; sliderTo: 3.0; sliderStep: 0.1 }
                        ConfigRow { label: t("オート表示", "Auto Mode", "自动模式", "자동 모드", "Modo automático", "Mode automatique", "Auto-Modus", "Авторежим"); ConfigCheckBox { id: autoModeToggle } }
                        ConfigSliderRow { id: autoSpeedRow;  label: t("オート待機時間", "Auto Wait Time", "自动等待时间", "자동 대기 시간", "Tiempo de espera", "Temps d'attente", "Wartezeit", "Время ожидания"); sliderFrom: 1.0; sliderTo: 10.0; sliderStep: 0.1; showAsSeconds: true }
                        Item { Layout.fillHeight: true }
                    }

                    // ── サウンド設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 2
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigSliderRow { id: masterVolRow; label: t("マスター音量", "Master Volume", "主音量", "마스터 볼륨", "Volumen maestro", "Volume principal", "Hauptlautstärke", "Громкость"); sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        ConfigSliderRow { id: bgmVolRow;    label: t("BGM音量", "BGM Volume", "BGM音量", "BGM 볼륨", "Volumen BGM", "Volume BGM", "BGM-Lautstärke", "BGM");     sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        ConfigSliderRow { id: seVolRow;     label: t("SE音量", "SE Volume", "音效音量", "SE 볼륨", "Volumen efectos", "Volume effets", "Effekte", "SE");      sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        ConfigSliderRow { id: voiceVolRow;  label: t("ボイス音量", "Voice Volume", "语音音量", "음성 볼륨", "Volumen de voz", "Volume voix", "Stimme", "Голос");   sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        Item { Layout.fillHeight: true }
                    }

                    // ── グラフィック設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 3
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigRow { label: t("画面モード", "Screen Mode", "屏幕模式", "화면 모드", "Modo de pantalla", "Mode d'écran", "Bildschirmmodus", "Экран"); ConfigComboBox { id: screenModeCombo; model: root.screenModeModel } }
                        ConfigRow { label: t("解像度", "Resolution", "分辨率", "해상도", "Resolución", "Résolution", "Auflösung", "Разрешение"); ConfigComboBox { id: resolutionCombo; model: ["1920x1080", "1600x900", "1280x720"] } }
                        Item { Layout.fillHeight: true }
                    }

                    // ── API設定 ──
                    // Unity Page_API VLG spacing=0 (different from other pages!)
                    ColumnLayout {
                        visible: root.activeCategory === 4
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 0
                        ConfigRow { label: t("LLM APIプロバイダ", "LLM API Provider", "LLM提供商", "LLM 제공자", "Proveedor LLM", "Fournisseur LLM", "LLM-Anbieter", "Провайдер"); ConfigComboBox { id: providerCombo; model: root.providerNames; popupMaxHeight: 500; onCurrentIndexChanged: root.onProviderChanged(currentIndex) } }
                        ConfigRow { label: t("APIキー", "API Key", "API密钥", "API 키", "Clave API", "Clé API", "API-Schlüssel", "Ключ API"); visible: providerCombo.currentIndex !== 4; ConfigTextField { id: apiKeyField; echoMode: TextField.Password } }
                        ConfigRow { label: t("LLM モデル名", "LLM Model Name", "模型名称", "모델명", "Nombre del modelo", "Nom du modèle", "Modellname", "Имя модели"); ConfigTextField { id: modelNameField } }
                        ConfigRow { label: t("LLM Web検索", "LLM Web Search", "网络搜索", "웹 검색", "Búsqueda web", "Recherche web", "Websuche", "Веб-поиск"); ConfigCheckBox { id: webSearchToggle } }
                        ConfigRow { label: t("Vertex Project ID", "Vertex Project ID", "Vertex 项目 ID", "Vertex 프로젝트 ID", "Vertex Project ID", "Vertex Project ID", "Vertex Projekt-ID", "Vertex ID проекта"); visible: providerCombo.currentIndex === 4; ConfigTextField { id: vertexProjectField } }
                        ConfigRow { label: t("Vertex Location", "Vertex Location", "Vertex 位置", "Vertex 위치", "Vertex Ubicación", "Vertex Emplacement", "Vertex Standort", "Vertex Регион"); visible: providerCombo.currentIndex === 4; ConfigTextField { id: vertexLocationField } }
                        ConfigRow { label: t("Ollama Host", "Ollama Host", "Ollama 主机", "Ollama 호스트", "Host Ollama", "Hôte Ollama", "Ollama-Host", "Хост Ollama"); visible: providerCombo.currentIndex === 5; ConfigTextField { id: ollamaHostField } }
                        // Unity: VertexInfoText row (info text, no control)
                Text {
                    visible: providerCombo.currentIndex === 4
                    Layout.preferredHeight: 100
                    Layout.fillWidth: true
                    text: styledText(t(
                        "※ Vertexを使用するためには、gCloud CLIのインストールが必要です。",
                        "* gCloud CLI is required to use Vertex.",
                        "* 使用Vertex需要安装gCloud CLI。",
                        "* Vertex를 사용하려면 gCloud CLI가 필요합니다。",
                        "* Se requiere gCloud CLI.",
                        "* gCloud CLI est requis.",
                        "* gCloud CLI wird benötigt.",
                        "* Требуется gCloud CLI."
                    ))
                    textFormat: Text.StyledText
                    color: "#FFFFFF"
                    font { family: root._fontFamily; pixelSize: 24 }
                    verticalAlignment: Text.AlignVCenter
                }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    // ─── Footer buttons ───
    Row {
        id: footerRow
        anchors { right: parent.right; rightMargin: 100; bottom: parent.bottom; bottomMargin: 60 }
        spacing: 50

        Rectangle {
            width: 210; height: 70
            color: "#4D4D4D"
            Text {
                id: cancelBtnText
                anchors.centerIn: parent
                text: styledText(t("キャンセル", "Cancel", "取消", "취소", "Cancelar", "Annuler", "Abbrechen", "Отмена"))
                textFormat: Text.RichText
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 32 }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { AppSettings.setInt("Config_Language", root.originalLang); AppSettings.save(); root.closed(); }
            }
        }

        Rectangle {
            width: 260; height: 70
            color: "#FF9900"
            Text {
                id: applyBtnText
                anchors.centerIn: parent
                text: styledText(t("適用", "Apply", "应用", "적용", "Aplicar", "Appliquer", "Anwenden", "Применить"))
                textFormat: Text.RichText
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 32 }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.saveSettings(); root.closed(); }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Backspace) {
            root.saveSettings(); root.closed(); event.accepted = true;
            return;
        }

        var up   = (event.key === Qt.Key_W || event.key === Qt.Key_Up);
        var down = (event.key === Qt.Key_S || event.key === Qt.Key_Down);
        if (up || down) {
            var next = root.activeCategory + (up ? -1 : 1);
            if (next < 0) next = root.categoryNames.length - 1;
            if (next >= root.categoryNames.length) next = 0;
            root.activeCategory = next;
            event.accepted = true;
        }
    }

    // ─── Fade ───
    opacity: 0
    onVisibleChanged: { if (visible) { root.opacity = 0; loadSettings(); Qt.callLater(function(){ root.opacity = 1; }); } }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    onClosed: {
        root.opacity = 0;
        closeTimer.start();
    }
    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.visible = false
    }

    // ── ConfigRow ──
    component ConfigRow: RowLayout {
        property string label: ""
        default property alias content: holder.data
        Layout.preferredHeight: 100
        Layout.fillWidth: true
        spacing: 300
        Text {
            id: rowLabelText
            text: styledText(label)
            textFormat: Text.RichText
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 24 }
            Layout.preferredWidth: 100
            Layout.minimumWidth: 100
            Layout.alignment: Qt.AlignVCenter
            Connections {
                target: root
                function onLangChanged() {
                    rowLabelText.text = styledText(label);
                }
            }
        }
        Item {
            id: holder
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 40
        }
    }

    // ── ConfigCheckBox ──
    component ConfigCheckBox: Item {
        id: checkRoot
        property bool checked: false
        width: 40; height: 40

        Rectangle {
            anchors.fill: parent
            color: "#333333"

            Rectangle {
                anchors.centerIn: parent
                width: 24; height: 24
                color: "#FF9900"
                visible: checkRoot.checked
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: checkRoot.checked = !checkRoot.checked
        }
    }

    // ── ConfigSliderRow ──
    // Unity: Slider 300×20, Background=#333, Fill=#FF9900, Handle=#FFF 20×40
    //        Value text: 80×40, 36px white, right-aligned
    //        Row: HLG spacing=300, Label width=100, childControlWidth=false
    //        Layout: Label(0-100) gap(300) Slider(400-700) gap(300) Value(1000-1080)
    component ConfigSliderRow: RowLayout {
        property string label: ""
        property real sliderFrom: 0
        property real sliderTo: 1
        property real sliderStep: 0.05
        property alias sliderValue: _slider.value
        property bool showAsSeconds: false

        Layout.preferredHeight: 100
        Layout.fillWidth: true
        spacing: 300

        // Label (width=100, same as Unity RectTransform)
        Text {
            id: sliderRowLabelText
            text: styledText(label)
            textFormat: Text.RichText
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 24 }
            Layout.preferredWidth: 100
            Layout.minimumWidth: 100
            Layout.alignment: Qt.AlignVCenter
            Connections {
                target: root
                function onLangChanged() {
                    sliderRowLabelText.text = styledText(label);
                }
            }
        }

        // Custom-rendered slider (300×20)
        Item {
            Layout.preferredWidth: 300
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            // Track background
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 10; color: "#333333"
            }

            // Fill bar
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * _slider.visualPosition
                height: 10; color: "#FF9900"
            }

            // Handle visual
            Rectangle {
                width: 20; height: 40; color: "#FFFFFF"
                x: Math.max(0, Math.min(parent.width - 20,
                    parent.width * _slider.visualPosition - 10))
                anchors.verticalCenter: parent.verticalCenter
            }

            // Invisible slider for interaction
            Slider {
                id: _slider
                anchors.fill: parent
                from: sliderFrom; to: sliderTo; stepSize: sliderStep
                background: Item {}
                handle: Item {
                    x: _slider.leftPadding + _slider.visualPosition * (_slider.availableWidth - width)
                    y: _slider.topPadding + _slider.availableHeight / 2 - height / 2
                    width: 20; height: 40
                }
            }
        }

        // Value display (80×40, 36px white)
        Text {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            text: showAsSeconds ? _slider.value.toFixed(1) + "s" : Math.round(_slider.value / _slider.to * 100) + "%"
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 36 }
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ── ConfigComboBox ──
    component ConfigComboBox: ComboBox {
        id: comboRoot
        implicitWidth: 400; implicitHeight: 50
        property int popupMaxHeight: 400
        focusPolicy: Qt.NoFocus
        activeFocusOnTab: false

        onActiveFocusChanged: {
            if (activeFocus) root.forceActiveFocus()
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down ||
                event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                event.accepted = true
            }
        }

        background: Rectangle {
            color: "#1A1A1A"; border.color: "#333333"; border.width: 1
        }

        contentItem: Text {
            leftPadding: 12
            text: styledText(comboRoot.displayText)
            textFormat: Text.StyledText
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 24 }
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Item {
            x: comboRoot.width - 15 - (width/2)
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20
            Image {
                id: arrowImg
                anchors.fill: parent
                source: "qrc:/qt/qml/RealAmadeusPC/resources/images/DownAllow.png"
                fillMode: Image.PreserveAspectFit
                visible: false
            }
            MultiEffect {
                anchors.fill: arrowImg
                source: arrowImg
                colorization: 1.0
                colorizationColor: "#FF9900"
            }
        }

        popup: Popup {
            y: comboRoot.height; width: comboRoot.width
            implicitHeight: Math.min(contentItem.implicitHeight, comboRoot.popupMaxHeight); padding: 1
            focus: false

            background: Rectangle { color: "#1A1A1A"; border.color: "#333333"; border.width: 1 }

            contentItem: ListView {
                focus: false
                clip: true; implicitHeight: contentHeight
                model: comboRoot.popup.visible ? comboRoot.delegateModel : null
                ScrollIndicator.vertical: ScrollIndicator {}

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Down ||
                        event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        event.accepted = true
                    }
                }
            }

            onClosed: {
                root.forceActiveFocus()
            }
        }

        delegate: ItemDelegate {
            width: comboRoot.width; height: 50
            background: Rectangle { color: highlighted ? "#111111" : "#1A1A1A" }
            contentItem: Text {
                text: styledText(modelData)
                textFormat: Text.StyledText
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 24 }
                verticalAlignment: Text.AlignVCenter; leftPadding: 12
            }
            highlighted: comboRoot.highlightedIndex === index
        }
    }

    // ── ConfigTextField ──
    // Unity InputField style: matching dropdown colors
    component ConfigTextField: TextField {
        id: fieldRoot
        implicitWidth: 400; implicitHeight: 50
        color: "#FFFFFF"
        font { family: root._fontFamily; pixelSize: 24 }
        verticalAlignment: Text.AlignVCenter; leftPadding: 12

        background: Rectangle {
            color: "#1A1A1A"
            border.color: fieldRoot.activeFocus ? "#FF9900" : "#333333"
            border.width: 1
        }

        placeholderTextColor: "#666666"
    }
}
