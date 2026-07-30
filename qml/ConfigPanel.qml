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

    property string importStatusText: ""
    property bool importSuccess: false
    property var chatPanelRef: null

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

    readonly property string _fontFamily: "Noto Serif CJK JP"

    // Hybrid font rendering
    // Korean: Hangul → Noto Serif, other → Noto Serif CJK JP
    // Russian: Cyrillic → Noto Serif CJK JP + letter-spacing -8.4, other → Noto Serif CJK JP
    function styledText(text, tighterCyrillic) {
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

        function isCyrillicI(c) {
            var code = c.charCodeAt(0);
            return (code === 0x0406 || code === 0x0456 || code === 0x0407 || code === 0x0457);
        }

        function isCyrillic(c) {
            var code = c.charCodeAt(0);
            return (code >= 0x0400 && code <= 0x04FF && !isCyrillicI(c));
        }

        var result = "";
        var hangulRun = "";
        var cyrillicRun = "";
        var cyrillicIRun = "";
        var otherRun = "";
        var krFace = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";

        function flushHangul() {
            if (hangulRun.length === 0) return;
            result += '<font face="' + krFace + '">' + escapeHtml(hangulRun) + '</font>';
            hangulRun = "";
        }
        function flushCyrillic() {
            if (cyrillicRun.length === 0) return;
            var spacing = "0px";
            result += '<span style="font-family: \'Noto Serif\', \'Noto Serif CJK JP\'; font-weight: 300; letter-spacing: ' + spacing + ';">' + escapeHtml(cyrillicRun) + '</span><span style="letter-spacing: 0px;"></span>';
            cyrillicRun = "";
        }
        function flushCyrillicI() {
            if (cyrillicIRun.length === 0) return;
            var spacing = "0px";
            result += '<span style="font-family: \'Noto Serif\', \'Noto Serif CJK JP\'; font-weight: 300; letter-spacing: ' + spacing + ';">' + escapeHtml(cyrillicIRun) + '</span><span style="letter-spacing: 0px;"></span>';
            cyrillicIRun = "";
        }
        function flushOther() {
            if (otherRun.length === 0) return;
            result += '<span style="font-family: \'Noto Serif\', \'Noto Serif CJK JP\'; font-weight: 300;">' + escapeHtml(otherRun) + '</span>';
            otherRun = "";
        }

        for (var i = 0; i < text.length; i++) {
            var c = text[i];
            if (lang === 3 && isHangul(c)) {
                flushCyrillic();
                flushCyrillicI();
                flushOther();
                hangulRun += c;
            } else if ((lang === 7 || lang === 8) && isCyrillic(c)) {
                flushHangul();
                flushCyrillicI();
                flushOther();
                cyrillicRun += c;
            } else if ((lang === 7 || lang === 8) && isCyrillicI(c)) {
                flushHangul();
                flushCyrillic();
                flushOther();
                cyrillicIRun += c;
            } else {
                flushHangul();
                flushCyrillic();
                flushCyrillicI();
                otherRun += c;
            }
        }
        flushHangul();
        flushCyrillic();
        flushCyrillicI();
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
            result += '<span style="font-family: \'Noto Serif\', \'Noto Serif CJK JP\'; font-weight: 300; letter-spacing: 0px;">' + escapeHtml(cyrillicRun) + '</span><span style="letter-spacing: 0px;"></span>';
            cyrillicRun = "";
        }
        function flushOther() {
            if (otherRun.length === 0) return;
            result += '<span style="font-family: \'Noto Serif\', \'Noto Serif CJK JP\'; font-weight: 300;">' + escapeHtml(otherRun) + '</span>';
            otherRun = "";
        }
        for (var i = 0; i < text.length; i++) {
            var c = text[i];
            if (isHangul(c)) {
                flushCyrillic();
                flushOther();
                hangulRun += c;
            } else if (isCyrillic(c)) {
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

    // Mutable language-dependent arrays (rebuilt on lang change)
    property var categoryNames: [
        t("category_system", "システム"),
        t("category_text", "テキスト"),
        t("category_sound", "サウンド"),
        t("category_graphics", "グラフィック"),
        t("category_api", "API")
    ]
    property var screenModeModel: [
        t("screen_mode_fullscreen", "フルスクリーン"),
        t("screen_mode_windowed", "ウィンドウ")
    ]
    property var chatLanguageNames: []

    function rebuildLocalizedArrays() {
        categoryNames = [
            t("category_system", "システム"),
            t("category_text", "テキスト"),
            t("category_sound", "サウンド"),
            t("category_graphics", "グラフィック"),
            t("category_api", "API")
        ];
        screenModeModel = [
            t("screen_mode_fullscreen", "フルスクリーン"),
            t("screen_mode_windowed", "ウィンドウ")
        ];
        chatLanguageNames = [
            t("setting_chat_lang_same_as_ui", "表示言語と同じ"),
            "日本語",
            "English",
            "中文",
            "한국어",
            "Español",
            "Français",
            "Deutsch",
            "Русский",
            "Українська",
            "Português",
            "Türkçe",
            "עברית",
            "العربية"
        ];
    }

    onLangChanged: {
        if (visible) {
            // Force Repeater delegate recreation by temporarily clearing model to apply new font settings
            sidebarRepeater.model = null;
            sidebarRepeater.model = root.categoryNames;
        }
    }

    FontLoader { id: notoKR; source: "file:///" + appDirPath + "/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) {
            return trans[key];
        }
        return defaultValue || key;
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
        "Русский",
        "Українська",
        "Português",
        "Türkçe",
        "עברית",
        "العربية"
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
            } else if (key === "Config_ChatLanguage") {
                var newChatLang = AppSettings.getInt("Config_ChatLanguage", 0);
                if (chatLanguageCombo.currentIndex !== newChatLang) {
                    root.suppressLanguageCommit = true;
                    chatLanguageCombo.currentIndex = newChatLang;
                    root.suppressLanguageCommit = false;
                }
            }
        }
    }

    Connections {
        target: Localization
        function onTranslationsChanged() {
            rebuildLocalizedArrays();
            if (visible) {
                sidebarRepeater.model = null;
                sidebarRepeater.model = root.categoryNames;
            }
            if (chatLanguageCombo) {
                var prevIndex = chatLanguageCombo.currentIndex;
                chatLanguageCombo.model = null;
                chatLanguageCombo.model = root.chatLanguageNames;
                chatLanguageCombo.currentIndex = prevIndex;
                if (chatLangComboText) {
                    chatLangComboText.text = styledLanguageName(root.chatLanguageNames[prevIndex] || "");
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
        chatLanguageCombo.currentIndex = Math.min(AppSettings.getInt("Config_ChatLanguage", 0), chatLanguageNames.length - 1);
        textSpeedRow.sliderValue   = AppSettings.getFloat("Config_TextSpeed", 1.0);
        autoSpeedRow.sliderValue   = AppSettings.getFloat("Config_AutoSpeed", 3.0);
        autoModeToggle.checked     = AppSettings.getInt("Config_AutoMode", 0) === 1;
        masterVolRow.sliderValue   = AppSettings.getFloat("Config_MasterVol", 1.0);
        bgmVolRow.sliderValue      = AppSettings.getFloat("Config_BGMVol", 0.8);
        seVolRow.sliderValue       = AppSettings.getFloat("Config_SEVol", 1.0);
        voiceVolRow.sliderValue    = AppSettings.getFloat("Config_VoiceVol", 1.0);
        screenModeCombo.currentIndex = AppSettings.getInt("Config_ScreenMode", 1);
        resolutionCombo.currentIndex = AppSettings.getInt("Config_Resolution", 0);
        webSearchToggle.checked    = AppSettings.getInt("Config_WebSearch", 0) === 1;
        providerCombo.currentIndex = currentProviderIndex;
        vertexProjectField.text    = AppSettings.getString("Config_VertexProject", "");
        vertexLocationField.text   = AppSettings.getString("Config_VertexLocation", "us-central1");
        ollamaHostField.text       = AppSettings.getString("Config_OllamaHost", "http://localhost:11434");
        openaiCompatibleToggle.checked = AppSettings.getInt("Config_OpenAICompatible", 0) === 1;
        openaiBaseUrlField.text    = AppSettings.getString("Config_OpenAIBaseUrl", "");
        root.suppressLanguageCommit = false;
    }

    function saveSettings() {
        apiKeyBuffer[currentProviderIndex]   = apiKeyField.text;
        modelNameBuffer[currentProviderIndex] = modelNameField.text;

        var newLang = languageCombo.currentIndex;
        AppSettings.setInt("Config_Language", newLang);
        root.lang = newLang;

        AppSettings.setInt("Config_ChatLanguage", chatLanguageCombo.currentIndex);

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
        AppSettings.setInt("Config_OpenAICompatible",   openaiCompatibleToggle.checked ? 1 : 0);
        AppSettings.setString("Config_OpenAIBaseUrl",   openaiBaseUrlField.text);

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

    function exportConversation() {
        if (!root.chatPanelRef || !root.chatPanelRef.conversationHistory) {
            root.importStatusText = t("export_no_data", "会話データがありません");
            root.importSuccess = false;
            return;
        }
        var timestamp = new Date().toISOString().replace(/[:.]/g, "-").substring(0, 19);
        var defaultPath = appDirPath + "/chat_export_" + timestamp + ".json";
        var filePath = ConversationIO.getSaveFileName(t("export_title", "会話記録の保存先を選択"), defaultPath, "JSON files (*.json)");
        if (filePath === "") {
            root.forceActiveFocus();
            return;
        }
        try {
            var history = root.chatPanelRef.conversationHistory;
            var exportMessages = [];
            for (var i = 0; i < history.length; i++) {
                if (history[i] && history[i].role !== "system") exportMessages.push(history[i]);
            }
            var exportData = {
                version: 1,
                exportedAt: new Date().toISOString(),
                turnCount: root.chatPanelRef.turnCount || 0,
                messages: exportMessages
            };
            var json = JSON.stringify(exportData, null, 2);
            ConversationIO.saveToFile(filePath, json);
            root.importStatusText = t("export_success", "エクスポート完了: ") + filePath;
            root.importSuccess = true;
            if (typeof AchievementManager !== "undefined" && AchievementManager) {
                AchievementManager.notifyEvent("export");
            }
        } catch (e) {
            root.importStatusText = t("export_failed", "エクスポート失敗: ") + e;
            root.importSuccess = false;
        }
        root.forceActiveFocus();
    }

    function importConversation() {
        var filePath = ConversationIO.getOpenFileName(t("import_title", "会話記録ファイルを選択"), appDirPath, "JSON files (*.json)");
        if (filePath === "") {
            root.forceActiveFocus();
            return;
        }
        try {
            var json = ConversationIO.loadFromFile(filePath);
            var data = JSON.parse(json);
            if (!data.messages || !Array.isArray(data.messages)) {
                root.importStatusText = t("import_invalid", "無効なファイル形式です");
                root.importSuccess = false;
                root.forceActiveFocus();
                return;
            }
            if (root.chatPanelRef) {
                root.chatPanelRef.conversationHistory = data.messages;
                root.chatPanelRef.turnCount = data.turnCount || 0;
                root.chatPanelRef.chatState = "inputReady";
                root.chatPanelRef.currentEmotionTag = "NORMAL";
                if (root.chatPanelRef.backLog) {
                    root.chatPanelRef.backLog.clearLog();
                    for (var i = 0; i < data.messages.length; i++) {
                        var msg = data.messages[i];
                        if (msg && msg.role !== "system") {
                            var roleLower = msg.role.toLowerCase();
                            if (roleLower === "assistant" || roleLower === "kurisu" || roleLower === "amadeus") {
                                var segments = (typeof root.chatPanelRef.splitMessage === "function")
                                    ? root.chatPanelRef.splitMessage(msg.content)
                                    : [msg.content];
                                for (var j = 0; j < segments.length; j++) {
                                    root.chatPanelRef.backLog.addLog(msg.role, segments[j]);
                                }
                            } else {
                                root.chatPanelRef.backLog.addLog(msg.role, msg.content);
                            }
                        }
                    }
                }
            }
            root.importStatusText = t("import_success", "インポート完了: ") + data.messages.length + t("import_turns", " ターン");
            root.importSuccess = true;
            if (typeof AchievementManager !== "undefined" && AchievementManager) {
                AchievementManager.notifyEvent("import");
            }
        } catch (e) {
            root.importStatusText = t("import_failed", "インポート失敗: ") + e;
            root.importSuccess = false;
        }
        root.forceActiveFocus();
    }

    // ─── Background ───
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/RealAmadeusPC/resources/images/Amadeus_BG.png"
        fillMode: Image.Stretch
    }

    // Clicking empty areas restores keyboard focus to the panel root
    MouseArea {
        anchors.fill: parent
        onClicked: root.forceActiveFocus()
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
                        ConfigRow { label: t("setting_display_language", "表示言語"); ConfigComboBox {
                            id: languageCombo; model: root.languageNames;
                            contentItem: Text {
                                id: langComboText
                                leftPadding: 12
                                text: styledLanguageName(root.languageNames[languageCombo.currentIndex] || "")
                                textFormat: Text.RichText
                                color: "#FFFFFF"
                                font { family: root._fontFamily; pixelSize: 24; weight: Font.Light }
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignLeft
                                elide: Text.ElideRight
                                Connections {
                                    target: languageCombo
                                    function onCurrentIndexChanged() {
                                        langComboText.text = styledLanguageName(root.languageNames[languageCombo.currentIndex] || "");
                                    }
                                }
                            }
                            delegate: ItemDelegate {
                                width: languageCombo.width * languageCombo.popup.scaleFactor
                                height: 50 * languageCombo.popup.scaleFactor
                                background: Rectangle { color: highlighted ? "#111111" : "#1A1A1A" }
                                contentItem: Text {
                                    text: styledLanguageName(modelData)
                                    textFormat: Text.RichText
                                    color: "#FFFFFF"
                                    font { family: root._fontFamily; pixelSize: 24 * languageCombo.popup.scaleFactor; weight: Font.Light }
                                    verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignLeft; leftPadding: 12 * languageCombo.popup.scaleFactor
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
                        ConfigRow { label: t("setting_chat_language", "会話言語"); ConfigComboBox {
                            id: chatLanguageCombo; model: root.chatLanguageNames;
                            contentItem: Text {
                                id: chatLangComboText
                                leftPadding: 12
                                text: styledLanguageName(root.chatLanguageNames[chatLanguageCombo.currentIndex] || "")
                                textFormat: Text.RichText
                                color: "#FFFFFF"
                                font { family: root._fontFamily; pixelSize: 24; weight: Font.Light }
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignLeft
                                elide: Text.ElideRight
                                Connections {
                                    target: chatLanguageCombo
                                    function onCurrentIndexChanged() {
                                        chatLangComboText.text = styledLanguageName(root.chatLanguageNames[chatLanguageCombo.currentIndex] || "");
                                    }
                                }
                            }
                            delegate: ItemDelegate {
                                width: chatLanguageCombo.width * chatLanguageCombo.popup.scaleFactor
                                height: 50 * chatLanguageCombo.popup.scaleFactor
                                background: Rectangle { color: highlighted ? "#111111" : "#1A1A1A" }
                                contentItem: Text {
                                    text: styledLanguageName(modelData)
                                    textFormat: Text.RichText
                                    color: "#FFFFFF"
                                    font { family: root._fontFamily; pixelSize: 24 * chatLanguageCombo.popup.scaleFactor; weight: Font.Light }
                                    verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignLeft; leftPadding: 12 * chatLanguageCombo.popup.scaleFactor
                                }
                                highlighted: chatLanguageCombo.highlightedIndex === index
                            }
                            onCurrentIndexChanged: {
                                if (root.suppressLanguageCommit || !root.visible || currentIndex === -1) return;
                                if (currentIndex !== AppSettings.getInt("Config_ChatLanguage", 0)) {
                                    AppSettings.setInt("Config_ChatLanguage", currentIndex);
                                    AppSettings.save();
                                }
                            }
                        } }
                        ConfigRow { label: t("setting_skip_loading", "起動画面スキップ"); ConfigCheckBox { id: skipLoadingToggle } }
                        ConfigRow { label: t("setting_right_click", "右クリックメニュー"); ConfigCheckBox { id: rightClickToggle } }
                        ConfigRow { label: t("setting_eye_tracking", "視線トラッキング"); ConfigCheckBox { id: eyeTrackingToggle } }
                        ConfigRow { label: t("setting_show_notifications", "通知を表示"); ConfigCheckBox { id: notificationsToggle } }
                        ConfigRow { label: t("setting_lightweight", "軽量化モード"); ConfigCheckBox { id: lightweightToggle } }
                        Item { Layout.fillHeight: true }
                    }

                    // ── テキスト設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 1
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigSliderRow { id: textSpeedRow;  label: t("setting_text_speed", "文字表示速度"); sliderFrom: 0.1; sliderTo: 3.0; sliderStep: 0.1 }
                        ConfigRow { label: t("setting_auto_mode", "オート表示"); ConfigCheckBox { id: autoModeToggle } }
                        ConfigSliderRow { id: autoSpeedRow;  label: t("setting_auto_speed", "オート待機時間"); sliderFrom: 1.0; sliderTo: 10.0; sliderStep: 0.1; showAsSeconds: true }

                        Rectangle { Layout.preferredHeight: 1; Layout.fillWidth: true; color: "#333333" }

                        ConfigRow { label: t("setting_export_chat", "会話記録エクスポート")
                            Rectangle {
                                width: 200; height: 45; color: "#FF9900"
                                Text { anchors.centerIn: parent; text: t("export", "書き出す"); color: "#FFF"; font { family: root._fontFamily; pixelSize: 24 } }
                                MouseArea { anchors.fill: parent; onClicked: root.exportConversation() }
                            }
                        }
                        ConfigRow { label: t("setting_import_chat", "会話記録インポート")
                            Rectangle {
                                width: 200; height: 45; color: "#4D4D4D"
                                Text { anchors.centerIn: parent; text: t("import", "読み込む"); color: "#FFF"; font { family: root._fontFamily; pixelSize: 24 } }
                                MouseArea { anchors.fill: parent; onClicked: root.importConversation() }
                            }
                        }
                        Text {
                            visible: root.importStatusText !== ""
                            Layout.fillWidth: true
                            text: root.importStatusText
                            color: root.importSuccess ? "#00CC00" : "#FF4444"
                            font { family: root._fontFamily; pixelSize: 20 }
                            wrapMode: Text.WrapAnywhere
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // ── サウンド設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 2
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigSliderRow { id: masterVolRow; label: t("setting_master_vol", "マスター音量"); sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        ConfigSliderRow { id: bgmVolRow;    label: t("setting_bgm_vol", "BGM音量");     sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        ConfigSliderRow { id: seVolRow;     label: t("setting_se_vol", "SE音量");      sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        ConfigSliderRow { id: voiceVolRow;  label: t("setting_voice_vol", "ボイス音量");   sliderFrom: 0; sliderTo: 1; sliderStep: 0.05 }
                        Item { Layout.fillHeight: true }
                    }

                    // ── グラフィック設定 ──
                    ColumnLayout {
                        visible: root.activeCategory === 3
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 15
                        ConfigRow { label: t("setting_screen_mode", "画面モード"); ConfigComboBox { id: screenModeCombo; model: root.screenModeModel } }
                        ConfigRow { label: t("setting_resolution", "解像度"); ConfigComboBox { id: resolutionCombo; model: ["1920x1080", "1600x900", "1280x720"] } }
                        Item { Layout.fillHeight: true }
                    }

                    // ── API設定 ──
                    // Unity Page_API VLG spacing=0 (different from other pages!)
                    ColumnLayout {
                        visible: root.activeCategory === 4
                        anchors { fill: parent; leftMargin: 40; rightMargin: 40 }
                        spacing: 0
                        ConfigRow { label: t("setting_api_provider", "LLM APIプロバイダ"); ConfigComboBox { id: providerCombo; model: root.providerNames; popupMaxHeight: 500; onCurrentIndexChanged: root.onProviderChanged(currentIndex) } }
                        ConfigRow { label: t("setting_api_key", "APIキー"); visible: providerCombo.currentIndex !== 4 && providerCombo.currentIndex !== 5; ConfigTextField { id: apiKeyField; echoMode: TextField.Password } }
                        ConfigRow {
                            label: t("setting_openai_compatible", "互換APIを使う")
                            visible: providerCombo.currentIndex === 0
                            ConfigCheckBox { id: openaiCompatibleToggle }
                        }
                        ConfigRow {
                            label: t("setting_openai_base_url", "ベースURL")
                            visible: providerCombo.currentIndex === 0 && openaiCompatibleToggle.checked
                            ConfigTextField { id: openaiBaseUrlField }
                        }
                        Text {
                            visible: providerCombo.currentIndex === 0 && openaiCompatibleToggle.checked
                            Layout.leftMargin: 400
                            Layout.preferredHeight: 30
                            Layout.fillWidth: true
                            text: styledText(t("setting_openai_base_url_example", "ベースURLの例: https://api.example.com/v1"))
                            textFormat: Text.StyledText
                            color: "#FFFFFF"
                            font { family: root._fontFamily; pixelSize: 20; weight: Font.Light }
                            verticalAlignment: Text.AlignTop
                        }
                        ConfigRow { label: t("setting_model_name", "LLM モデル名"); ConfigTextField { id: modelNameField } }
                        ConfigRow { label: t("setting_web_search", "LLM Web検索"); ConfigCheckBox { id: webSearchToggle } }
                        ConfigRow { label: t("setting_vertex_project", "Vertex Project ID"); visible: providerCombo.currentIndex === 4; ConfigTextField { id: vertexProjectField } }
                        ConfigRow { label: t("setting_vertex_location", "Vertex Location"); visible: providerCombo.currentIndex === 4; ConfigTextField { id: vertexLocationField } }
                        ConfigRow { label: t("setting_ollama_host", "Ollama Host"); visible: providerCombo.currentIndex === 5; ConfigTextField { id: ollamaHostField } }
                        // Unity: VertexInfoText row (info text, no control)
                Text {
                    visible: providerCombo.currentIndex === 4
                    Layout.preferredHeight: 100
                    Layout.fillWidth: true
                    text: styledText(t("setting_vertex_note", "※ Vertexを使用するためには、gCloud CLIのインストールが必要です。"))
                    textFormat: Text.StyledText
                    color: "#FFFFFF"
                    font { family: root._fontFamily; pixelSize: 24; weight: Font.Light }
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
                text: styledText(t("cancel", "キャンセル"), true)
                textFormat: Text.RichText
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 32 }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (AppSettings.getInt("Config_Language", 0) !== root.originalLang) {
                        AppSettings.setInt("Config_Language", root.originalLang);
                        AppSettings.save();
                    }
                    root.loadSettings();
                    root.closed();
                }
            }
        }

        Rectangle {
            width: 260; height: 70
            color: "#FF9900"
            Text {
                id: applyBtnText
                anchors.centerIn: parent
                text: styledText(t("apply", "適用"), true)
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
        spacing: 0
        Text {
            id: rowLabelText
            text: styledText(label)
            textFormat: Text.RichText
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 24 }
            wrapMode: Text.Wrap
            rightPadding: 30
            Layout.preferredWidth: 400
            Layout.minimumWidth: 400
            Layout.maximumWidth: 400
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
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
            onClicked: { checkRoot.checked = !checkRoot.checked; root.forceActiveFocus(); }
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
        spacing: 0

        // Label (width=400, text wraps within 370, 30px padding/gap)
        Text {
            id: sliderRowLabelText
            text: styledText(label)
            textFormat: Text.RichText
            color: "#FFFFFF"
            font { family: root._fontFamily; pixelSize: 24 }
            wrapMode: Text.Wrap
            rightPadding: 30
            Layout.preferredWidth: 400
            Layout.minimumWidth: 400
            Layout.maximumWidth: 400
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
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

        // Spacer to maintain the 300px gap before value display
        Item {
            Layout.preferredWidth: 300
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
        property int popupMaxHeight: 550
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
            font { family: root._fontFamily; pixelSize: 24; weight: Font.Light }
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
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
            id: comboPopup
            parent: Overlay.overlay
            readonly property real scaleFactor: Math.min(mainWindow.width / 1920.0, mainWindow.height / 1080.0)
            x: 0
            y: 0
            width: comboRoot.width * scaleFactor
            implicitHeight: (comboRoot.count * 50 + 2) * scaleFactor
            padding: 1 * scaleFactor
            focus: false

            onAboutToShow: {
                var pt = comboRoot.mapToItem(null, 0, comboRoot.height);
                x = pt.x;
                y = pt.y;
            }

            background: Rectangle {
                color: "#1A1A1A"
                border.color: "#333333"
                border.width: 1 * comboPopup.scaleFactor
            }

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
            width: comboRoot.width * comboPopup.scaleFactor
            height: 50 * comboPopup.scaleFactor
            background: Rectangle { color: highlighted ? "#111111" : "#1A1A1A" }
            contentItem: Text {
                text: styledText(modelData)
                textFormat: Text.StyledText
                color: "#FFFFFF"
                font { family: root._fontFamily; pixelSize: 24 * comboPopup.scaleFactor; weight: Font.Light }
                verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignLeft; leftPadding: 12 * comboPopup.scaleFactor
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
        font { family: root._fontFamily; pixelSize: 24; weight: Font.Light }
        verticalAlignment: Text.AlignVCenter; leftPadding: 12

        onActiveFocusChanged: {
            if (!activeFocus) root.forceActiveFocus()
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.forceActiveFocus()
                event.accepted = true
            }
        }

        background: Rectangle {
            color: "#1A1A1A"
            border.color: fieldRoot.activeFocus ? "#FF9900" : "#333333"
            border.width: 1
        }

        placeholderTextColor: "#666666"
    }
}
