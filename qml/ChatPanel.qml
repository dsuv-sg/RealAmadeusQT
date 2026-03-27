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
        (root.chatState === "typing" &&
         typewriterTimer.running &&
         !root.isWaitingForInput &&
         root.typewriterIndex < root.typewriterText.length) ||
        (root.chatState === "streamingTyping" &&
         streamTypewriterTimer.running &&
         !root.isWaitingForInput &&
         streamTypewriterTimer.displayIndex < root.streamBuffer.length)

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
        
        // Initialize Status Panel with current settings (Unity parity line 478)
        root.updateStatusPanelStats(0);
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
                dialogueText.text = "";
                root.lastLoggedPageText = "";
                root.typewriterClearPageOnResume = false;
                waitingIndicator.text = "";
            }

            // Skip leading whitespace after page clear (Unity parity)
            if (root.typewriterIndex < root.typewriterText.length && dialogueText.text.length === 0) {
                var ch = root.typewriterText.charAt(root.typewriterIndex);
                while (root.typewriterIndex < root.typewriterText.length && (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r')) {
                    root.typewriterIndex++;
                    if (root.typewriterIndex < root.typewriterText.length)
                        ch = root.typewriterText.charAt(root.typewriterIndex);
                }
            }

            if (root.skipTyping) {
                dialogueText.text = root.typewriterText.substring(root.typewriterStartIndex);
                root.typewriterIndex = root.typewriterText.length;
                stop();
                root.skipTyping = false;
                root.isWaitingForInput = false;
                if (dialogueText.text.trim().length > 0 && dialogueText.text !== root.lastLoggedPageText) {
                    if (root.backLog) root.backLog.addLog("assistant", dialogueText.text);
                    root.lastLoggedPageText = dialogueText.text;
                }
                setState("waitForAdvance");
                return;
            }

            if (root.typewriterIndex < root.typewriterText.length) {
                var c = root.typewriterText.charAt(root.typewriterIndex);
                root.typewriterIndex++;
                dialogueText.text = root.typewriterText.substring(root.typewriterStartIndex, root.typewriterIndex);

                var nextC = (root.typewriterIndex < root.typewriterText.length)
                            ? root.typewriterText.charAt(root.typewriterIndex)
                            : "";
                var pause = root.isPauseCharacter(c, nextC);
                if (pause) {
                    root.isWaitingForInput = true;
                    root.skipTyping = false;
                    autoTimer.accumulated = 0;
                    root.typewriterClearPageOnResume = root.typewriterIndex < root.typewriterText.length;
                    if (dialogueText.text.trim().length > 0) {
                        if (root.backLog) root.backLog.addLog("assistant", dialogueText.text);
                        root.lastLoggedPageText = dialogueText.text;
                    }
                    waitingIndicator.text = "▼";
                    return;
                }

                typewriterTimer.interval = root.charDelayForChar(c);
            } else {
                stop();
                root.isWaitingForInput = false;
                if (dialogueText.text.trim().length > 0 && dialogueText.text !== root.lastLoggedPageText) {
                    if (root.backLog) root.backLog.addLog("assistant", dialogueText.text);
                    root.lastLoggedPageText = dialogueText.text;
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
                dialogueText.text = "";
                root.lastStreamLoggedPageText = "";
                root.streamClearPageOnResume = false;
                waitingIndicator.text = "";
            }

            // Skip leading whitespace after page clear (Unity parity)
            if (displayIndex < root.streamBuffer.length && dialogueText.text.length === 0) {
                var wc = root.streamBuffer.charAt(displayIndex);
                while (displayIndex < root.streamBuffer.length && (wc === ' ' || wc === '\t' || wc === '\n' || wc === '\r')) {
                    displayIndex++;
                    if (displayIndex < root.streamBuffer.length)
                        wc = root.streamBuffer.charAt(displayIndex);
                }
            }

            if (root.skipTyping) {
                dialogueText.text = root.streamBuffer.substring(root.streamStartIndex);
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
                dialogueText.text = root.streamBuffer.substring(root.streamStartIndex, displayIndex);

                var nextC = (displayIndex < root.streamBuffer.length)
                            ? root.streamBuffer.charAt(displayIndex)
                            : "";
                var pause = root.isPauseCharacter(c, nextC);
                if (pause) {
                    root.isWaitingForInput = true;
                    root.skipTyping = false;
                    autoTimer.accumulated = 0;
                    root.streamClearPageOnResume = (displayIndex < root.streamBuffer.length || !root.streamComplete);
                    if (dialogueText.text.trim().length > 0) {
                        if (root.backLog) root.backLog.addLog("assistant", dialogueText.text);
                        root.lastStreamLoggedPageText = dialogueText.text;
                    }
                    waitingIndicator.text = "▼";
                    return;
                }

                streamTypewriterTimer.interval = root.charDelayForChar(c);
            } else if (root.streamComplete) {
                stop();
                root.isWaitingForInput = false;
                if (dialogueText.text.trim().length > 0 && dialogueText.text !== root.lastStreamLoggedPageText) {
                    if (root.backLog) root.backLog.addLog("assistant", dialogueText.text);
                    root.lastStreamLoggedPageText = dialogueText.text;
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
        // Also strip <think>...</think>
        text = text.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
        // Strip [TAG] patterns
        var cleaned = text.replace(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/gi, "").trim();
        return cleaned;
    }

    function parseEmotionTag(text) {
        var m = text.match(/\[(NORMAL|SMILE|ANGRY|SAD|SURPRISED|BLUSH|WINK|DISGUST|SMUG|THINKING|PANIC)\]/i);
        return m ? m[1].toUpperCase() : "NORMAL";
    }

    function isPauseCharacter(c, nextC) {
        var pause = (c === "。" || c === "！" || c === "？" || c === "!" || c === "?" || c === "\n");
        if (!pause)
            return false;

        if (nextC === "」" || nextC === "）" || nextC === ")" || nextC === "』" || nextC === "”")
            return false;

        return true;
    }

    // ─── Cached text speed (avoid per-char AppSettings lookup) ───
    property real cachedTextSpeed: AppSettings.getFloat("Config_TextSpeed", 1.0)
    Connections {
        target: AppSettings
        function onSettingsChanged(key) {
            if (key === "Config_TextSpeed")
                root.cachedTextSpeed = AppSettings.getFloat("Config_TextSpeed", 1.0);
        }
    }

    function charDelayForChar(c) {
        var base = 1000.0 / 20.0 / Math.max(0.1, root.cachedTextSpeed);
        if (c === "、" || c === "," || c === "…")
            return base * 2.5;
        if (c === "」" || c === "）")
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
                dialogueText.text = "";
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
            waitingIndicator.text = "▼";
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

        if (provider === 3 || provider === 4) {
            // Groq or Vertex: streaming
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
        var text = response.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();

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
        dialogueText.text = "";
        setState("typing");
        typewriterTimer.charDelay = 1000.0 / 20.0 / Math.max(0.1, AppSettings.getFloat("Config_TextSpeed", 1.0));
        typewriterTimer.restart();
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

            // Strip <think> blocks
            buf = buf.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();

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
            } else if (buf.length > 2 && !buf.startsWith("<")) {
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
            dialogueText.text = "";
            setState("typing");
            typewriterTimer.charDelay = 1000.0 / 20.0 / Math.max(0.1, root.cachedTextSpeed);
            typewriterTimer.restart();
        }
        // If it was streaming, streamTypewriterTimer will finish on its own since streamComplete is true.
    }

    function onAPIError(error) {
        console.warn("[ChatPanel] onAPIError:", error);
        waitingDotsTimer.stop();

        // In-character error messages (Unity parity)
        var kurisuMessage;
        if (error.indexOf("API Key") >= 0 || error.indexOf("API key") >= 0 || error.indexOf("設定されていません") >= 0) {
            kurisuMessage = "……APIキーが設定されてないみたいよ。CONFIGから設定してちょうだい。";
        } else if (error.indexOf("401") >= 0 || error.indexOf("Unauthorized") >= 0) {
            kurisuMessage = "APIキーが無効みたい……もう一度確認して設定し直してくれる？";
        } else if (error.indexOf("429") >= 0 || error.indexOf("rate limit") >= 0 || error.indexOf("quota") >= 0) {
            kurisuMessage = "リクエストが多すぎるみたい。少し待ってからもう一度試してくれない？";
        } else if (error.indexOf("timeout") >= 0 || error.indexOf("Timeout") >= 0) {
            kurisuMessage = "応答がタイムアウトしたわ……ネットワークの状態を確認してみて。";
        } else if (error.indexOf("Cannot connect") >= 0 || error.indexOf("Network") >= 0 || error.indexOf("ネットワーク") >= 0) {
            kurisuMessage = "ネットワークに接続できないわ。インターネット接続を確認してちょうだい。";
        } else if (error.indexOf("403") >= 0 || error.indexOf("Forbidden") >= 0) {
            kurisuMessage = "このAPIへのアクセスが拒否されたわ。権限を確認してみて。";
        } else if (error.indexOf("500") >= 0 || error.indexOf("502") >= 0 || error.indexOf("503") >= 0) {
            kurisuMessage = "サーバー側でエラーが起きてるみたい。しばらくしてからもう一度試して。";
        } else if (error.indexOf("model") >= 0 || error.indexOf("Model") >= 0) {
            kurisuMessage = "指定されたモデルが見つからないみたい。CONFIGからモデル名を確認して。";
        } else if (error.indexOf("gcloud") >= 0 || error.indexOf("アクセストークン") >= 0) {
            kurisuMessage = "Vertex AIの認証に失敗したわ。gcloudの設定を確認してみて。";
        } else {
            kurisuMessage = "何かエラーが起きたみたい……もう一度試してくれる？";
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
        dialogueText.text = "";
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
        width: parent.width * 3
        height: parent.height * 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -parent.height * 0.55 - 1500
        z: -1
        transform: Scale {
            origin.x: kurisuLive2D.width * 0.5
            origin.y: kurisuLive2D.height * 0.5
            yScale: -1
        }

        modelPath: "AmadeusKurisu5.0/reama5.0"
        emotion: root.currentEmotionTag
        // C++ model generates natural mouth motion internally while this value > 0.
        // QML only provides a clean on/off speaking gate.
        lipSyncValue: root.isActivelySpeaking ? 1.0 : 0.0
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
            text: root.configLanguage === 1 ? "Amadeus Kurisu" : "アマデウス紅莉栖"
            color: "#ffffff"
            font { family: "MS Mincho"; pixelSize: 36 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }

        // Unity System.unity parity: DialogueText (1280x50, center, y=+92)
        Text {
            id: dialogueText
            width: 1280
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -12
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            color: "#ffffff"
            font { family: "MS Mincho"; pixelSize: 36 }
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignTop
            lineHeight: 1.0
            clip: false
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

        // Wait/advance arrow (▼)
        // Arrow display is unified into waitingIndicator text in setState().
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
                placeholderText: root.configLanguage === 1 ? "Enter your message..." : "メッセージを入力"
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
}
