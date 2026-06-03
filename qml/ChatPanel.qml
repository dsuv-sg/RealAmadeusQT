import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Amadeus.Live2D 1.0

/// ChatPanel - mirrors AmadeusChatController.cs
/// Handles chat input, typewriter display, streaming, emotion tag stripping,
/// and API communication via C++ AIService backend.
Item {
    id: root
    clip: true
    property bool chatDebug: true

    signal openMenu()

    property bool autoMode: false
    property real autoSpeed: 3.0
    property int configLanguage: AppSettings.getInt("Config_Language", 0)
    property var  backLog: null
    property bool menuPanelOpen: false

    readonly property var thinkRegex: new RegExp(String.fromCharCode(60) + "think" + String.fromCharCode(62) + "[\\s\\S]*?" + String.fromCharCode(60) + "\\/think" + String.fromCharCode(62), "gi")

    // ─── Chat state ───
    // "inputReady" | "waitingAPI" | "typing" | "streamingTyping" | "waitForAdvance"
    property string chatState: "inputReady"
    property string currentFullText: ""
    property bool skipTyping: false
    property bool isWaitingForInput: false
    property string currentEmotionTag: "NORMAL"
    property string lastLoggedPageText: ""
    property string lastStreamLoggedPageText: ""
    property int turnCount: 0

    // Typewriter paging properties
    property bool typewriterClearPageOnResume: false
    property bool streamClearPageOnResume: false
    property bool streamComplete: false
    property int typewriterStartIndex: 0
    property int streamStartIndex: 0

    onEnabledChanged: {
        if (enabled && root.chatState !== "inputReady") {
            keyboardHandler.forceActiveFocus();
        }
    }

    // Streaming
    property string streamBuffer: ""
    property bool streamEmotionParsed: false
    property string streamEmotionTag: "NORMAL"

    // Auto mode timer
    property real autoTimer: 0

    readonly property bool isConversationPausedByMenuState: menuPanelOpen

    // True only while text is actively being revealed on screen.
    readonly property bool isActivelySpeaking:
        !root.isConversationPausedByMenuState && (
            (root.chatState === "typing" &&
             typewriterTimer.running &&
             !root.isWaitingForInput &&
             root.typewriterIndex < root.typewriterText.length) ||
            (root.chatState === "streamingTyping" &&
             streamTypewriterTimer.running &&
             !root.isWaitingForInput &&
             streamTypewriterTimer.displayIndex < root.streamBuffer.length)
        )

    // Conversation history: [{role: "system"|"user"|"assistant", content: "..."}]
    property var conversationHistory: []

    // ─── System prompt (short version) ───
    readonly property string systemPrompt: "あなたは牧瀬紅莉栖（まきせ くりす）。Amadeusシステム上で再現されたAI人格。\n" +
        "天才脳科学者（18歳）であり、論理的思考を好むが、実は隠れ＠ちゃんねらー（ネット民）。\n" +
        "性格はツンデレ。素直になれないが、根は優しく仲間想い。\n" +
        "自分はオリジナルではなく「Amadeus」というAIであることを認識している。\n\n" +
        "【重要：感情タグ（必須）】\n" +
        "返答の冒頭に【必ず1つだけ】以下のタグを付けること。タグと本文の間にはスペースを入れる。\n" +
        "[NORMAL] [SMILE] [ANGRY] [SAD] [SURPRISED] [BLUSH] [WINK] [DISGUST] [SMUG] [THINKING] [PANIC]\n\n" +
        "例：\n[BLUSH] べ、別に心配なんてしてないんだから！\n[ANGRY] このHENTAI！海馬に電極ぶっ刺すわよ！\n\n" +
        "【口調】一人称：「私」。基本：知的で冷静、少し辛辣。「〜ね」「〜よ」「〜わ」\n" +
        "回答は短く端的に（1〜5文推奨）。「AIです」という自己紹介は不要。同じ語尾やフレーズを繰り返さない。"

    // ─── Network request start time ───
    property real requestStartTime: 0

    FontLoader { id: notoKR; source: "file:///" + Qt.application.dirPath + "/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    function t(key, defaultValue) {
        var trans = Localization.translations;
        if (trans && trans[key] !== undefined) {
            return trans[key];
        }
        return defaultValue || key;
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

        if (Array.isArray(text)) {
            var html = "";
            for (var i = 0; i < text.length; i++) {
                var seg = text[i];
                var segText = seg.text || "";
                var segFont = seg.font || "MS Mincho";
                var segSpacing = seg.letterSpacing !== undefined ? seg.letterSpacing : 0.0;
                
                if (segFont === "Noto Serif CJK KR" || segFont === "Noto Serif CJK") {
                    var family = notoKR.status === FontLoader.Ready ? notoKR.name : "Noto Serif CJK KR";
                    html += '<span style="font-family: \'' + family + '\';">' + escapeHtml(segText) + '</span>';
                } else if (segSpacing !== 0.0) {
                    html += '<span style="font-family: \'' + segFont + '\'; letter-spacing: ' + segSpacing + 'px;">' + escapeHtml(segText) + '</span>';
                } else {
                    html += '<span style="font-family: \'' + segFont + '\';">' + escapeHtml(segText) + '</span>';
                }
            }
            return '<span style="font-size: ' + pixelSize + 'px;">' + html + '</span>';
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

    Component.onCompleted: {
        // Initialize conversation with system prompt
        var history = [];
        var memCtx = MemoryManager.getMemoryContext();
        var sysContent = systemPrompt;
        if (memCtx.length > 0) sysContent += "\n\n" + memCtx;
        history.push({ role: "system", content: sysContent });
        root.conversationHistory = history;

        setState("inputReady");

        // Connect AIService signals
        AIService.responseReceived.connect(root.onAPISuccess);
        AIService.streamToken.connect(root.onStreamToken);
        AIService.streamComplete.connect(root.onStreamComplete);
        AIService.errorOccurred.connect(root.onAPIError);

        // Force text refresh to ensure correct language rendering on startup
        Qt.callLater(function() {
            var name = t("amadeus_kurisu", "アマデウス紅莉栖");
            nameText.text = mixedTextHtml(name, 36);
            forceTextRefresh();
        });
    }

    // ─── Auto-mode advance timer ───
    Timer {
        id: autoTimer
        interval: 100
        repeat: true
        running: root.autoMode &&
                 !root.isConversationPausedByMenuState &&
                 (root.chatState === "waitForAdvance" ||
                  (root.isWaitingForInput &&
                   (root.chatState === "typing" || root.chatState === "streamingTyping")))
        property real accumulated: 0
        onTriggered: {
            accumulated += 0.1;
            if (accumulated >= root.autoSpeed) {
                accumulated = 0;
                if (root.chatState === "waitForAdvance") {
                    setState("inputReady");
                } else if (root.isWaitingForInput) {
                    root.isWaitingForInput = false;
                }
            }
        }
        onRunningChanged: {
            if (!running) accumulated = 0;
        }
    }

    // ─── Typewriter timer ───
    property int typewriterIndex: 0
    property string typewriterText: ""

    Timer {
        id: typewriterTimer
        property real charDelay: 1000.0 / 20.0 / Math.max(0.1, AppSettings.getFloat("Config_TextSpeed", 1.0))
        interval: charDelay
        repeat: true
        onTriggered: {
            if (root.isConversationPausedByMenuState)
                return;

            if (root.isWaitingForInput)
                return;

            if (root.typewriterClearPageOnResume) {
                root.typewriterStartIndex = root.typewriterIndex;
                dialogueText.rawText = "";
                root.lastLoggedPageText = "";
                root.typewriterClearPageOnResume = false;
                waitingIndicator.text = "";
            }

            // Skip leading whitespace after page clear (Unity parity)
            if (root.typewriterIndex < root.typewriterText.length && dialogueText.rawText.length === 0) {
                var ch = root.typewriterText.charAt(root.typewriterIndex);
                while (root.typewriterIndex < root.typewriterText.length && (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r')) {
                    root.typewriterIndex++;
                    if (root.typewriterIndex < root.typewriterText.length)
                        ch = root.typewriterText.charAt(root.typewriterIndex);
                }
            }

            if (root.skipTyping) {
                dialogueText.rawText = root.typewriterText.substring(root.typewriterStartIndex);
                root.typewriterIndex = root.typewriterText.length;
                stop();
                root.skipTyping = false;
                root.isWaitingForInput = false;
                if (dialogueText.rawText.trim().length > 0 && dialogueText.rawText !== root.lastLoggedPageText) {
                    if (root.backLog) root.backLog.addLog("assistant", dialogueText.rawText);
                    root.lastLoggedPageText = dialogueText.rawText;
                }
                setState("waitForAdvance");
                return;
            }

            if (root.typewriterIndex < root.typewriterText.length) {
                var c = root.typewriterText.charAt(root.typewriterIndex);
                root.typewriterIndex++;
                dialogueText.rawText = root.typewriterText.substring(root.typewriterStartIndex, root.typewriterIndex);

                var nextC = (root.typewriterIndex < root.typewriterText.length)
                            ? root.typewriterText.charAt(root.typewriterIndex)
                            : "";
                var pause = root.isPauseCharacter(c, nextC);
                if (pause) {
                    root.isWaitingForInput = true;
                    root.skipTyping = false;
                    autoTimer.accumulated = 0;
                    root.typewriterClearPageOnResume = root.typewriterIndex < root.typewriterText.length;
                    if (dialogueText.rawText.trim().length > 0) {
                        if (root.backLog) root.backLog.addLog("assistant", dialogueText.rawText);
                        root.lastLoggedPageText = dialogueText.rawText;
                    }
                    waitingIndicator.text = "▼";
                    return;
                }

                typewriterTimer.interval = root.charDelayForChar(c);
            } else {
                stop();
                root.isWaitingForInput = false;
                if (dialogueText.rawText.trim().length > 0 && dialogueText.rawText !== root.lastLoggedPageText) {
                    if (root.backLog) root.backLog.addLog("assistant", dialogueText.rawText);
                    root.lastLoggedPageText = dialogueText.rawText;
                }
                setState("waitForAdvance");
            }
        }
    }

    // ─── Streaming typewriter ───
    Timer {
        id: streamTypewriterTimer
        interval: 30
        repeat: true
        property int displayIndex: 0
        onTriggered: {
            if (root.isConversationPausedByMenuState)
                return;

            if (root.isWaitingForInput)
                return;

            if (root.streamClearPageOnResume) {
                root.streamStartIndex = displayIndex;
                dialogueText.rawText = "";
                root.lastStreamLoggedPageText = "";
                root.streamClearPageOnResume = false;
                waitingIndicator.text = "";
            }

            // Skip leading whitespace after page clear (Unity parity)
            if (displayIndex < root.streamBuffer.length && dialogueText.rawText.length === 0) {
                var wc = root.streamBuffer.charAt(displayIndex);
                while (displayIndex < root.streamBuffer.length && (wc === ' ' || wc === '\t' || wc === '\n' || wc === '\r')) {
                    displayIndex++;
                    if (displayIndex < root.streamBuffer.length)
                        wc = root.streamBuffer.charAt(displayIndex);
                }
            }

            if (root.skipTyping) {
                dialogueText.rawText = root.streamBuffer.substring(root.streamStartIndex);
                displayIndex = root.streamBuffer.length;
                if (root.chatState !== "streamingTyping") { stop(); }
                return;
            }

            if (displayIndex < root.streamBuffer.length) {
                var c = root.streamBuffer.charAt(displayIndex);

                if (c === "[") {
                    var closeIdx = root.streamBuffer.indexOf("]", displayIndex);
                    if (closeIdx > displayIndex) {
                        var tag = root.streamBuffer.substring(displayIndex + 1, closeIdx).toUpperCase();
                        if (/^(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)$/.test(tag)) {
                            root.currentEmotionTag = tag;
                            displayIndex = closeIdx + 1;
                            return;
                        }
                    }
                }

                displayIndex++;
                dialogueText.rawText = root.streamBuffer.substring(root.streamStartIndex, displayIndex);

                var nextC = (displayIndex < root.streamBuffer.length)
                            ? root.streamBuffer.charAt(displayIndex)
                            : "";
                var pause = root.isPauseCharacter(c, nextC);
                if (pause) {
                    root.isWaitingForInput = true;
                    root.skipTyping = false;
                    autoTimer.accumulated = 0;
                    root.streamClearPageOnResume = (displayIndex < root.streamBuffer.length || !root.streamComplete);
                    if (dialogueText.rawText.trim().length > 0) {
                        if (root.backLog) root.backLog.addLog("assistant", dialogueText.rawText);
                        root.lastStreamLoggedPageText = dialogueText.rawText;
                    }
                    waitingIndicator.text = "▼";
                    return;
                }

                streamTypewriterTimer.interval = root.charDelayForChar(c);
            } else if (root.streamComplete) {
                stop();
                root.isWaitingForInput = false;
                if (dialogueText.rawText.trim().length > 0 && dialogueText.rawText !== root.lastStreamLoggedPageText) {
                    if (root.backLog) root.backLog.addLog("assistant", dialogueText.rawText);
                    root.lastStreamLoggedPageText = dialogueText.rawText;
                }
                setState("waitForAdvance");
            } else if (root.chatState !== "streamingTyping") {
                stop();
            }
        }
    }

    // ─── Utility ───
    function stripEmotionTag(text) {
        var validTags = ["NORMAL","SMILE","ANGRY","SAD","SURPRISED","BLUSH","WINK","DISGUST","SMUG","THINKING","PANIC"];
        text = text.trim();
        // Also strip think blocks
        var thinkRegex = root.thinkRegex;
        text = text.replace(thinkRegex, "").trim();
        // Strip [TAG] patterns
        var cleaned = text.replace(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/gi, "").trim();
        return cleaned;
    }

    function parseEmotionTag(text) {
        var m = text.match(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/i);
        return m ? m[1].toUpperCase() : "NORMAL";
    }

    function isPauseCharacter(c, nextC) {
        var pause = (c === "\u3002" || c === "\uff01" || c === "\uff1f" || c === "!" || c === "?" || c === "\n");
        if (!pause)
            return false;

        if (nextC === "\u300d" || nextC === "\uff09" || nextC === ")" || nextC === "\u300f" || nextC === "\u201d")
            return false;

        return true;
    }

    // ─── Cached text speed (avoid per-char AppSettings lookup) ───
    property real cachedTextSpeed: AppSettings.getFloat("Config_TextSpeed", 1.0)
    property bool eyeTrackingEnabled: AppSettings.getInt("Config_EyeTracking", 0) === 1
    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_TextSpeed")
                root.cachedTextSpeed = AppSettings.getFloat("Config_TextSpeed", 1.0);
            if (key === "Config_Language")
                root.configLanguage = AppSettings.getInt("Config_Language", 0);
            if (key === "Config_EyeTracking")
                root.eyeTrackingEnabled = AppSettings.getInt("Config_EyeTracking", 0) === 1;
        }
    }

    function forceTextRefresh() {
        function refresh(item) {
            if (item.text !== undefined && item.textFormat !== undefined && (item.textFormat === Text.RichText || item.textFormat === Text.StyledText)) {
                var old = item.text;
                item.text = "";
                item.text = old;
            }
            if (item.children !== undefined) {
                for (var i = 0; i < item.children.length; i++) {
                    refresh(item.children[i]);
                }
            }
            if (item.contentItem !== undefined && item.contentItem !== item) {
                refresh(item.contentItem);
            }
        }
        refresh(root);
    }

    onConfigLanguageChanged: {
        var name = t("amadeus_kurisu", "アマデウス紅莉栖");
        nameText.text = mixedTextHtml(name, 36);
        Qt.callLater(forceTextRefresh);
    }

    function charDelayForChar(c) {
        var base = 1000.0 / 20.0 / Math.max(0.1, root.cachedTextSpeed);
        if (c === "\u3001" || c === "," || c === "\u2026")
            return base * 2.5;
        if (c === "\u300d" || c === "\uff09")
            return base * 1.5;
        return base;
    }

    function updateSystemPrompt() {
        var sysContent = systemPrompt;
        var memCtx = MemoryManager.getMemoryContext();
        if (memCtx.length > 0) sysContent += "\n\n" + memCtx;
        var dynCtx = MemoryManager.getDynamicContext(root.turnCount);
        if (dynCtx.length > 0) sysContent += "\n\n" + dynCtx;
        if (root.conversationHistory.length > 0 && root.conversationHistory[0].role === "system") {
            var h = root.conversationHistory.slice();
            h[0] = { role: "system", content: sysContent };
            root.conversationHistory = h;
        }
    }

    function setState(newState) {
        if (root.chatDebug) console.log("[ChatPanel] setState", root.chatState, "->", newState);
        root.chatState = newState;
        if (newState === "inputReady") {
            if (chatInput) {
                chatInput.enabled = true;
                chatInput.forceActiveFocus();
            }
            root.currentEmotionTag = "NORMAL";
            waitingDotsTimer.stop();
            waitingIndicator.text = "";
        } else if (newState === "waitingAPI") {
            if (chatInput) {
                chatInput.enabled = false;
            }
            if (dialogueText) {
                dialogueText.rawText = "";
            }
            waitingIndicator.text = ".";
            waitingDotsTimer.restart();
        } else if (newState === "typing" || newState === "streamingTyping") {
            if (chatInput) {
                chatInput.enabled = false;
            }
            waitingDotsTimer.stop();
            waitingIndicator.text = "";
        } else if (newState === "waitForAdvance") {
            autoTimer.accumulated = 0;
            if (chatInput) {
                chatInput.enabled = false;
            }
            waitingDotsTimer.stop();
            waitingIndicator.text = "\u25bc";
        }
    }

    function submitMessage(text) {
        if (root.chatDebug) console.log("[ChatPanel] submitMessage(raw)=", text, "state=", root.chatState);
        text = text.trim();
        if (text.length === 0) return;
        if (root.chatState !== "inputReady") return;

        chatInput.text = "";
        chatInput.enabled = false;

        var h = root.conversationHistory.slice();
        h.push({ role: "user", content: text });
        root.conversationHistory = h;
        root.turnCount++;

        // Trim history
        if (typeof MemoryManager !== "undefined" && MemoryManager) {
            try {
                MemoryManager.trimConversationHistory(root.conversationHistory, 30);
                MemoryManager.recordInteraction();
            } catch (e) {
                console.warn("[ChatPanel] MemoryManager error:", e);
            }
        }

        updateSystemPrompt();

        // Backlog
        try {
            if (root.backLog) root.backLog.addLog("user", text);
        } catch (e2) {
            console.warn("[ChatPanel] BackLog error:", e2);
        }

        root.requestStartTime = Date.now();
        setState("waitingAPI");
        sendCurrentConversationToAI();
    }

    function sendCurrentConversationToAI() {
        // Send only after an explicit user submission.
        var provider = AppSettings.getInt("Config_ApiProvider", 0);
        root.streamBuffer = "";
        root.streamEmotionParsed = false;
        root.streamEmotionTag = "NORMAL";
        root.streamComplete = false;

        if (typeof AIService === "undefined" || !AIService) {
            onAPIError("AIService is unavailable in QML context.");
            return;
        }

        if (provider === 3 || provider === 4 || provider === 5 || provider === 6) {
            // Groq, Vertex, Ollama, or OpenRouter: streaming
            streamTypewriterTimer.displayIndex = 0;
            if (root.chatDebug) console.log("[ChatPanel] sendChatStreaming, messages=", root.conversationHistory.length);
            AIService.sendChatStreaming(root.conversationHistory);
        } else {
            if (root.chatDebug) console.log("[ChatPanel] sendChat, messages=", root.conversationHistory.length);
            AIService.sendChat(root.conversationHistory);
        }
    }

    // ─── Latency Measurement & Stats Update (Unity parity) ───
    function updateStatusPanelStats(latencyMs) {
        var providerIdx = AppSettings.getInt("Config_ApiProvider", 0);
        var providerName = "Unknown";
        var modelName = AppSettings.getString("Config_ModelName_" + providerIdx, "");
        if (modelName === "") modelName = AppSettings.getString("Config_ModelName", "default");

        switch (providerIdx) {
            case 0: providerName = "OpenAI"; break;
            case 1: providerName = "Gemini"; break;
            case 2: providerName = "Claude"; break;
            case 3: providerName = "Groq"; break;
            case 4: providerName = "Vertex AI"; break;
            case 5: providerName = "Ollama"; break;
            case 6: providerName = "OpenRouter"; break;
        }

        // Global update via Main Window properties
        if (typeof mainWindow !== "undefined") {
            mainWindow.llmProvider = providerName;
            mainWindow.llmModel    = modelName;
            mainWindow.llmLatency  = latencyMs;
        }

        // Update local status panel instance directly
        if (root.statusPanelRef) {
            root.statusPanelRef.updateLLMStats(providerName, modelName, latencyMs);
        }
    }

    function onAPISuccess(response) {
        if (root.chatDebug) console.log("[ChatPanel] onAPISuccess len=", (response || "").length);
        waitingDotsTimer.stop();

        // ─── Latency Measurement End ───
        var latency = Date.now() - root.requestStartTime;
        root.updateStatusPanelStats(latency);

        // Strip thinking tags
        var thinkRegex = root.thinkRegex;
        var text = response.replace(thinkRegex, "").trim();

        var tag = parseEmotionTag(text);
        root.currentEmotionTag = tag;
        var display = stripEmotionTag(text);

        MemoryManager.recordEmotion(tag);

        var h = root.conversationHistory.slice();
        h.push({ role: "assistant", content: display });
        root.conversationHistory = h;

        // Start typewriter
        root.currentFullText = display;
        root.typewriterText = display;
        root.typewriterIndex = 0;
        root.typewriterStartIndex = 0;
        root.skipTyping = false;
        root.isWaitingForInput = false;
        root.typewriterClearPageOnResume = false;
        root.lastLoggedPageText = "";
        dialogueText.rawText = "";
        setState("typing");
        typewriterTimer.charDelay = 1000.0 / 20.0 / Math.max(0.1, AppSettings.getFloat("Config_TextSpeed", 1.0));
        typewriterTimer.restart();

        // Notification
        if (AppSettings.getInt("Config_DesktopNotifications", 1) === 1 && typeof NotificationService !== "undefined" && NotificationService) {
                NotificationService.show(t("amadeus", "アマデウス"), display.substring(0, 100));
        }
    }

    function onStreamToken(token) {
        if (root.chatDebug && token && token.length > 0) console.log("[ChatPanel] onStreamToken len=", token.length);

        // First token received -> Calculate Latency (Time to First Token)
        if (!root.streamEmotionParsed && root.streamBuffer === "") {
            var latency = Date.now() - root.requestStartTime;
            root.updateStatusPanelStats(latency);
        }

        if (!root.streamEmotionParsed) {
            root.streamBuffer += token;
            var buf = root.streamBuffer;

            // Strip think blocks
            var thinkRegex = root.thinkRegex;
            buf = buf.replace(thinkRegex, "").trim();

            // Try to parse emotion tag
            if (buf.startsWith("[")) {
                var closeIdx = buf.indexOf("]");
                if (closeIdx > 0) {
                    root.streamEmotionTag = buf.substring(1, closeIdx).toUpperCase();
                    root.streamEmotionParsed = true;
                    root.currentEmotionTag = root.streamEmotionTag;
                    MemoryManager.recordEmotion(root.streamEmotionTag);
                    root.streamBuffer = buf.substring(closeIdx + 1).trimStart();
                    setState("streamingTyping");
                    streamTypewriterTimer.displayIndex = 0;
                    root.streamStartIndex = 0;
                    streamTypewriterTimer.restart();
                }
            } else if (buf.length > 2 && !buf.startsWith(String.fromCharCode(60))) {
                root.streamEmotionParsed = true;
                root.streamEmotionTag = "NORMAL";
                root.currentEmotionTag = "NORMAL";
                root.streamBuffer = buf;
                setState("streamingTyping");
                streamTypewriterTimer.displayIndex = 0;
                root.streamStartIndex = 0;
                streamTypewriterTimer.restart();
            }
        } else {
            root.streamBuffer += token;
        }
    }

    function onStreamComplete(fullResponse) {
        if (root.chatDebug) console.log("[ChatPanel] onStreamComplete len=", (fullResponse || "").length);
        waitingDotsTimer.stop();
        root.streamComplete = true;

        var display = stripEmotionTag((fullResponse || "").trim());
        if (display.length === 0)
            display = stripEmotionTag(root.streamBuffer);

        if (!root.streamEmotionParsed) {
            root.currentEmotionTag = parseEmotionTag(fullResponse || root.streamBuffer);
            MemoryManager.recordEmotion(root.currentEmotionTag);
        }

        root.streamBuffer = display;

        var h = root.conversationHistory.slice();
        h.push({ role: "assistant", content: display });
        root.conversationHistory = h;

        root.streamEmotionParsed = false;
        root.streamEmotionTag = "NORMAL";

        if (root.chatState !== "streamingTyping") {
            // Did not stream effectively (came all at once). Start normal typewriter.
            root.currentFullText = display;
            root.typewriterText = display;
            root.typewriterIndex = 0;
            root.typewriterStartIndex = 0;
            root.skipTyping = false;
            root.isWaitingForInput = false;
            root.typewriterClearPageOnResume = false;
            root.lastLoggedPageText = "";
            dialogueText.rawText = "";
            setState("typing");
            typewriterTimer.charDelay = 1000.0 / 20.0 / Math.max(0.1, root.cachedTextSpeed);
            typewriterTimer.restart();

            // Notification
            if (AppSettings.getInt("Config_DesktopNotifications", 1) === 1 && typeof NotificationService !== "undefined" && NotificationService) {
            NotificationService.show(t("amadeus", "アマデウス"), display.substring(0, 100));
            }
        }
        // If it was streaming, streamTypewriterTimer will finish on its own since streamComplete is true.
    }

    function onAPIError(error) {
        console.warn("[ChatPanel] onAPIError:", error);
        waitingDotsTimer.stop();

        // In-character error messages (Unity parity)
        var kurisuMessage;
        if (error.indexOf("API Key") >= 0 || error.indexOf("API key") >= 0 || error.indexOf("\u8A2D\u5B9A\u3055\u308C\u3066\u3044\u307E\u305B\u3093") >= 0) {
            kurisuMessage = "\u2026\u2026API\u30AD\u30FC\u304C\u8A2D\u5B9A\u3055\u308C\u3066\u306A\u3044\u307F\u305F\u3044\u3088\u3002CONFIG\u304B\u3089\u8A2D\u5B9A\u3057\u3066\u3061\u3087\u3046\u3060\u3044\u3002";
        } else if (error.indexOf("401") >= 0 || error.indexOf("Unauthorized") >= 0) {
            kurisuMessage = "API\u30AD\u30FC\u304C\u7121\u52B9\u307F\u305F\u3044\u2026\u2026\u3082\u3046\u4E00\u5EA6\u78BA\u8A8D\u3057\u3066\u8A2D\u5B9A\u3057\u76F4\u3057\u3066\u304F\u308C\u308B\uFF1F";
        } else if (error.indexOf("429") >= 0 || error.indexOf("rate limit") >= 0 || error.indexOf("quota") >= 0) {
            kurisuMessage = "\u30EA\u30AF\u30A8\u30B9\u30C8\u304C\u591A\u3059\u304E\u308B\u307F\u305F\u3044\u3002\u5C11\u3057\u5F85\u3063\u3066\u304B\u3089\u3082\u3046\u4E00\u5EA6\u8A66\u3057\u3066\u304F\u308C\u306A\u3044\uFF1F";
        } else if (error.indexOf("timeout") >= 0 || error.indexOf("Timeout") >= 0) {
            kurisuMessage = "\u5FDC\u7B54\u304C\u30BF\u30A4\u30E0\u30A2\u30A6\u30C8\u3057\u305F\u308F\u2026\u2026\u30CD\u30C3\u30C8\u30EF\u30FC\u30AF\u306E\u72B6\u614B\u3092\u78BA\u8A8D\u3057\u3066\u307F\u3066\u3002";
        } else if (error.indexOf("Cannot connect") >= 0 || error.indexOf("Network") >= 0 || error.indexOf("\u30CD\u30C3\u30C8\u30EF\u30FC\u30AF") >= 0) {
            kurisuMessage = "\u30CD\u30C3\u30C8\u30EF\u30FC\u30AF\u306B\u63A5\u7D9A\u3067\u304D\u306A\u3044\u308F\u3002\u30A4\u30F3\u30BF\u30FC\u30CD\u30C3\u30C8\u63A5\u7D9A\u3092\u78BA\u8A8D\u3057\u3066\u3061\u3087\u3046\u3060\u3044\u3002";
        } else if (error.indexOf("403") >= 0 || error.indexOf("Forbidden") >= 0) {
            kurisuMessage = "\u3053\u306EAPI\u3078\u306E\u30A2\u30AF\u30BB\u30B9\u304C\u62D2\u5426\u3055\u308C\u305F\u308F\u3002\u6A29\u9650\u3092\u78BA\u8A8D\u3057\u3066\u307F\u3066\u3002";
        } else if (error.indexOf("500") >= 0 || error.indexOf("502") >= 0 || error.indexOf("503") >= 0) {
            kurisuMessage = "\u30B5\u30FC\u30D0\u30FC\u5074\u3067\u30A8\u30E9\u30FC\u304C\u8D77\u304D\u3066\u308B\u307F\u305F\u3044\u3002\u3057\u3070\u3089\u304F\u3057\u3066\u304B\u3089\u3082\u3046\u4E00\u5EA6\u8A66\u3057\u3066\u3002";
        } else if (error.indexOf("model") >= 0 || error.indexOf("Model") >= 0) {
            kurisuMessage = "\u6307\u5B9A\u3055\u308C\u305F\u30E2\u30C7\u30EB\u304C\u898B\u3064\u304B\u3089\u306A\u3044\u307F\u305F\u3044\u3002CONFIG\u304B\u3089\u30E2\u30C7\u30EB\u540D\u3092\u78BA\u8A8D\u3057\u3066\u3002";
        } else if (error.indexOf("gcloud") >= 0 || error.indexOf("\u30A2\u30AF\u30BB\u30B9\u30C8\u30FC\u30AF\u30F3") >= 0) {
            kurisuMessage = "Vertex AI\u306E\u8A8D\u8A3C\u306B\u5931\u6557\u3057\u305F\u308F\u3002gcloud\u306E\u8A2D\u5B9A\u3092\u78BA\u8A8D\u3057\u3066\u307F\u3066\u3002";
        } else {
            kurisuMessage = "\u4F55\u304B\u30A8\u30E9\u30FC\u304C\u8D77\u304D\u305F\u307F\u305F\u3044\u2026\u2026\u3082\u3046\u4E00\u5EA6\u8A66\u3057\u3066\u304F\u308C\u308B\uFF1F";
        }

        root.currentEmotionTag = "ANGRY";

        // Show as typewriter (Unity: error goes through typewriter too)
        root.currentFullText = kurisuMessage;
        root.typewriterText = kurisuMessage;
        root.typewriterIndex = 0;
        root.typewriterStartIndex = 0;
        root.skipTyping = false;
        root.isWaitingForInput = false;
        root.typewriterClearPageOnResume = false;
        root.lastLoggedPageText = "";
        dialogueText.rawText = "";
        setState("typing");
        typewriterTimer.charDelay = 1000.0 / 20.0 / Math.max(0.1, root.cachedTextSpeed);
        typewriterTimer.restart();
    }

    Shortcut {
        sequence: "Return"
        enabled: root.chatState === "inputReady" && chatInput.activeFocus
        onActivated: {
            var message = chatInput.text;
            if (message && message.trim().length > 0)
                root.submitMessage(message);
        }
    }

    function setEyeTracking(x, y) {
        kurisuLive2D.eyeX = x;
        kurisuLive2D.eyeY = y;
    }

    function resetEyeTracking() {
        setEyeTracking(0, 0);
    }

    Shortcut {
        sequence: "Enter"
        enabled: root.chatState === "inputReady" && chatInput.activeFocus
        onActivated: {
            var message = chatInput.text;
            if (message && message.trim().length > 0)
                root.submitMessage(message);
        }
    }

    // ─── Keyboard: Enter ───
    Item {
        id: keyboardHandler
        anchors.fill: parent
        focus: root.chatState !== "inputReady"
        Keys.onReturnPressed: (event) => {
            if (root.isConversationPausedByMenuState) {
                event.accepted = true;
                return;
            }

            if (root.chatState === "inputReady") {
                event.accepted = false;
                return;
            } else if (root.chatState === "typing" || root.chatState === "streamingTyping") {
                if (root.isWaitingForInput) root.isWaitingForInput = false;
                else root.skipTyping = true;
            } else if (root.chatState === "waitForAdvance") {
                setState("inputReady");
                chatInput.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    Timer {
        id: waitingDotsTimer
        interval: 400
        repeat: true
        property int dots: 1
        onTriggered: {
            if (root.chatState !== "waitingAPI") {
                stop();
                return;
            }
            dots = (dots % 3) + 1;
            waitingIndicator.text = ".".repeat(dots);
        }
    }

    // ─── Live2D Model ───
    Live2DItem {
        id: kurisuLive2D
        width: 3840
        height: 2160
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        z: -1
        transform: Scale {
            origin.x: kurisuLive2D.width * 0.5
            origin.y: kurisuLive2D.height * 0.5
            yScale: -1
        }

        modelPath: "AmadeusKurisu5.0/reama5.0"
        emotion: root.currentEmotionTag
        lipSyncValue: root.isActivelySpeaking ? 1.0 : 0.0
        lightweightMode: AppSettings.getInt("Config_LightweightMode", 0) === 1
    }

    // ─── UI Layout ───
    // Bottom 1/3: Dialogue panel
    Rectangle {
        id: dialoguePanel
        visible: root.chatState !== "inputReady"
        anchors {
            left: parent.left; right: parent.right
            bottom: parent.bottom
        }
        height: 300
        color: Qt.rgba(45/255, 15/255, 0/255, 239/255) // BackGround RGBA(45,15,0,239)

        // Unity System.unity parity: NameText (300x50, center, y=-112)
        Text {
            id: nameText
            width: 300
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 112
            text: mixedTextHtml(t("amadeus_kurisu", "アマデウス紅莉栖"), 36)
            textFormat: Text.RichText
            color: "#ffffff"
            font { pixelSize: 36 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            //wrapMode: Text.WordWrap
        }

        // Unity System.unity parity: DialogueText (1280x50, center, y=+92)
        Text {
            id: dialogueText
            property string rawText: ""
            width: 1280
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -12
            text: mixedTextHtml(rawText, 36)
            textFormat: Text.RichText
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            color: "#ffffff"
            font { pixelSize: 36 }
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignTop
            lineHeight: 1.0
            clip: false
            onRawTextChanged: {
                // Explicit update because function-call bindings sometimes fail to re-evaluate
                text = mixedTextHtml(rawText, 36);
            }
        }

        // Waiting indicator text (API Loading)
        Text {
            id: waitingIndicator
            width: 1770
            height: 132
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenterOffset: -5
            anchors.verticalCenterOffset: 49
            text: ""
            color: Qt.rgba(255/255, 153/255, 0/255, 204/255)
            font { family: "MS Mincho"; pixelSize: 28}
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignBottom
            wrapMode: Text.WordWrap
            visible: root.chatState === "waitingAPI" || root.chatState === "waitForAdvance" || root.isWaitingForInput
        }
    }

    // Input panel (above dialogue)
    Rectangle {
        id: inputPanel
        visible: root.chatState === "inputReady"
        anchors {
            left: parent.left; right: parent.right
            bottom: parent.bottom
            leftMargin: 50  // Unity: offsetMin.x = 40
            rightMargin: 50 // Unity: offsetMax.x = -40
            bottomMargin: 25 // Unity: anchoredPosition.y = 20
        }
        height: 60  // Unity: sizeDelta.y = 70
        color: "#4e1e15"

        // ChatInput Outline
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(255/255, 102/255, 0/255, 76/255)
            border.width: 1
        }

        RowLayout {
            anchors { fill: parent; margins: 5; leftMargin: 10; rightMargin: 10; topMargin: 5; bottomMargin: 5 }
            spacing: 10  // Unity: HorizontalLayoutGroup spacing = 10

            TextField {
                id: chatInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: t("enter_message", "メッセージを入力")
                placeholderTextColor: Qt.rgba(128/255, 128/255, 128/255, 153/255)
                color: "#ffffff"
                font { family: "MS Mincho"; pixelSize: 28; italic: chatInput.text.length === 0 }
                background: null
                focus: true

                // Caret & Selection
                cursorDelegate: Rectangle {
                    width: 1
                    color: "#ffffff"
                    visible: chatInput.activeFocus
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
                selectionColor: Qt.rgba(255/255, 153/255, 0/255, 76/255)
                selectedTextColor: "#ffffff"
                verticalAlignment: TextInput.AlignVCenter

                onAccepted: {
                    var message = chatInput.text;
                    if (root.chatState === "inputReady" && message.trim().length > 0)
                        root.submitMessage(message);
                }

                Keys.onReturnPressed: (event) => {
                    var message = chatInput.text;
                    if (root.chatState === "inputReady" && message.trim().length > 0) {
                        root.submitMessage(message);
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }

                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    // ─── Sub-panels (instantiated in-place) ───
    StatusPanel {
        id: statusPanel
        anchors.fill: parent
        visible: false
    }

    // Expose sub-panels for MenuPanel
    property alias statusPanelRef: statusPanel
    property alias live2DItem: kurisuLive2D
}
