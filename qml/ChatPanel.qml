import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// ChatPanel - mirrors AmadeusChatController.cs
/// Handles chat input, typewriter display, streaming, emotion tag stripping,
/// and API communication via C++ AIService backend.
Item {
    id: root

    signal openMenu()

    property bool autoMode: false
    property real autoSpeed: 3.0

    // ─── Chat state ───
    // "inputReady" | "waitingAPI" | "typing" | "streamingTyping" | "waitForAdvance"
    property string chatState: "inputReady"
    property string currentFullText: ""
    property bool skipTyping: false
    property bool isWaitingForInput: false
    property int turnCount: 0

    // Streaming
    property string streamBuffer: ""
    property bool streamEmotionParsed: false
    property string streamEmotionTag: "NORMAL"

    // Auto mode timer
    property real autoTimer: 0
    property string currentEmotionTag: "NORMAL"

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

        // Connect AIService signals
        AIService.responseReceived.connect(root.onAPISuccess);
        AIService.streamToken.connect(root.onStreamToken);
        AIService.streamComplete.connect(root.onStreamComplete);
        AIService.errorOccurred.connect(root.onAPIError);
    }

    // ─── Auto-mode advance timer ───
    Timer {
        id: autoTimer
        interval: 100
        repeat: true
        running: root.autoMode && (root.chatState === "waitForAdvance" ||
                                   (root.isWaitingForInput &&
                                    (root.chatState === "typing" || root.chatState === "streamingTyping")))
        property real accumulated: 0
        onTriggered: {
            accumulated += 0.1;
            if (accumulated >= root.autoSpeed) {
                accumulated = 0;
                if (root.chatState === "waitForAdvance") {
                    root.chatState = "inputReady";
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
        property real charDelay: 1000.0 / 10.0 / Math.max(0.1, AppSettings.getFloat("Config_TextSpeed", 1.0))
        interval: charDelay
        repeat: true
        onTriggered: {
            if (root.skipTyping) {
                dialogueText.text = root.typewriterText;
                root.typewriterIndex = root.typewriterText.length;
                stop();
                root.skipTyping = false;
                root.isWaitingForInput = false;
                root.chatState = "waitForAdvance";
                return;
            }
            if (root.typewriterIndex < root.typewriterText.length) {
                root.typewriterIndex++;
                dialogueText.text = root.typewriterText.substring(0, root.typewriterIndex);
            } else {
                stop();
                root.isWaitingForInput = false;
                root.chatState = "waitForAdvance";
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
            if (root.skipTyping) {
                dialogueText.text = root.streamBuffer;
                displayIndex = root.streamBuffer.length;
                if (root.chatState !== "streamingTyping") { stop(); }
                return;
            }
            if (displayIndex < root.streamBuffer.length) {
                displayIndex++;
                dialogueText.text = root.streamBuffer.substring(0, displayIndex);
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

    function submitMessage(text) {
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
        MemoryManager.trimConversationHistory(root.conversationHistory, 30);
        MemoryManager.recordInteraction();

        updateSystemPrompt();

        // Backlog
        backLogPanel.addLog("user", text);

        root.requestStartTime = Date.now();
        root.chatState = "waitingAPI";
        dialogueText.text = "";
        waitingIndicator.visible = true;

        // Choose streaming or not
        var provider = AppSettings.getInt("Config_ApiProvider", 0);
        root.streamBuffer = "";
        root.streamEmotionParsed = false;
        root.streamEmotionTag = "NORMAL";

        if (provider === 3 || provider === 4) {
            // Groq or Vertex: streaming
            streamTypewriterTimer.displayIndex = 0;
            AIService.sendChatStreaming(root.conversationHistory);
        } else {
            AIService.sendChat(root.conversationHistory);
        }
    }

    function onAPISuccess(response) {
        waitingIndicator.visible = false;
        chatInput.enabled = true;

        // Strip thinking tags
        var text = response.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();

        var tag = parseEmotionTag(text);
        root.currentEmotionTag = tag;
        var display = stripEmotionTag(text);

        MemoryManager.recordEmotion(tag);

        var h = root.conversationHistory.slice();
        h.push({ role: "assistant", content: display });
        root.conversationHistory = h;

        backLogPanel.addLog("assistant", display);

        // Start typewriter
        root.typewriterText = display;
        root.typewriterIndex = 0;
        root.skipTyping = false;
        root.isWaitingForInput = false;
        dialogueText.text = "";
        root.chatState = "typing";
        typewriterTimer.charDelay = 1000.0 / 10.0 / Math.max(0.1, AppSettings.getFloat("Config_TextSpeed", 1.0));
        typewriterTimer.restart();
    }

    function onStreamToken(token) {
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
                    root.chatState = "streamingTyping";
                    waitingIndicator.visible = false;
                    chatInput.enabled = true;
                    streamTypewriterTimer.displayIndex = 0;
                    streamTypewriterTimer.restart();
                }
            } else if (buf.length > 2 && !buf.startsWith("<")) {
                root.streamEmotionParsed = true;
                root.streamEmotionTag = "NORMAL";
                root.currentEmotionTag = "NORMAL";
                root.streamBuffer = buf;
                root.chatState = "streamingTyping";
                waitingIndicator.visible = false;
                chatInput.enabled = true;
                streamTypewriterTimer.displayIndex = 0;
                streamTypewriterTimer.restart();
            }
        } else {
            root.streamBuffer += token;
        }
    }

    function onStreamComplete(fullResponse) {
        streamTypewriterTimer.stop();
        waitingIndicator.visible = false;
        chatInput.enabled = true;

        var display = root.streamBuffer;

        var h = root.conversationHistory.slice();
        h.push({ role: "assistant", content: display });
        root.conversationHistory = h;

        backLogPanel.addLog("assistant", display);

        dialogueText.text = display;
        root.chatState = "waitForAdvance";
    }

    function onAPIError(error) {
        waitingIndicator.visible = false;
        chatInput.enabled = true;
        dialogueText.text = "[ERROR] " + error;
        root.currentEmotionTag = "ANGRY";
        root.chatState = "waitForAdvance";
    }

    // ─── Right-click → menu ───
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && AppSettings.getInt("Config_RightClickMenu", 1) === 1)
                root.openMenu();
        }
        propagateComposedEvents: true
    }

    // ─── Keyboard: Enter ───
    Item {
        anchors.fill: parent
        focus: true
        Keys.onReturnPressed: {
            if (root.chatState === "inputReady") {
                // handled by TextInput onAccepted
            } else if (root.chatState === "typing" || root.chatState === "streamingTyping") {
                if (root.isWaitingForInput) root.isWaitingForInput = false;
                else root.skipTyping = true;
            } else if (root.chatState === "waitForAdvance") {
                root.chatState = "inputReady";
                chatInput.forceActiveFocus();
            }
        }
    }

    // ─── UI Layout ───
    // Bottom 1/3: Dialogue panel
    Rectangle {
        id: dialoguePanel
        visible: false
        anchors {
            left: parent.left; right: parent.right
            bottom: parent.bottom
        }
        height: 300
        color: Qt.rgba(45/255, 15/255, 0/255, 239/255) // BackGround RGBA(45,15,0,239)

        RowLayout {
            anchors { fill: parent; margins: 20; leftMargin: 40; rightMargin: 40 }
            spacing: 40

            // Character name (NameText)
            Text {
                id: nameText
                text: "アマデウス紅莉栖"
                color: "#ffffff"
                font { family: "MS Mincho"; pixelSize: 36 }
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
            }

            // Dialogue text (DialogueText)
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Text {
                    id: dialogueText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#ffffff"
                    font { family: "MS Mincho"; pixelSize: 36 }
                    verticalAlignment: Text.AlignTop
                    lineHeight: 1.4
                }
            }
        }

        // Waiting indicator text (API Loading)
        Text {
            id: waitingIndicator
            anchors { right: parent.right; bottom: parent.bottom; margins: 20 }
            text: "通信中..."
            color: Qt.rgba(255/255, 153/255, 0/255, 204/255)
            font { family: "MS Mincho"; pixelSize: 28; italic: true }
            visible: root.chatState === "waitingAPI"
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: waitingIndicator.visible
                NumberAnimation { to: 1; duration: 500 }
                NumberAnimation { to: 0.2; duration: 500 }
            }
        }

        // Wait/advance arrow (▼)
        Text {
            visible: root.chatState === "waitForAdvance"
            anchors { right: parent.right; bottom: parent.bottom; margins: 20 }
            text: "▼"
            color: Qt.rgba(255/255, 153/255, 0/255, 204/255) // WaitingIndicator Orange
            font.pixelSize: 28
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: parent.visible
                NumberAnimation { to: 1; duration: 400 }
                NumberAnimation { to: 0.1; duration: 400 }
            }
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
                placeholderText: "メッセージを入力"
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

                Keys.onReturnPressed: {
                    if (root.chatState === "inputReady" && text.trim().length > 0)
                        root.submitMessage(text);
                }

                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    // ─── Sub-panels (instantiated in-place) ───
    BackLogPanel {
        id: backLogPanel
        anchors.fill: parent
        visible: false
    }

    StatusPanel {
        id: statusPanel
        anchors.fill: parent
        visible: false
    }

    // Expose sub-panels for MenuPanel
    property alias backLogRef: backLogPanel
    property alias statusPanelRef: statusPanel
}
