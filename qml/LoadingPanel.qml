import QtQuick
import QtQuick.Controls

/// BootSequence - mirrors BootSequenceLineByLine.cs
/// Terminal-style boot animation → Amadeus logo → signals bootFinished
Item {
    id: root
    signal bootFinished()

    // ─── Boot text content ───
    property string bootLog: "Amadeus System Ver 1.09.2 rev.2123\n" +
        ">>Initialize System ...  OK\n" +
        ">>Detecting boot device ... OK\n" +
        ">>Loading Kernel ...  OK\n" +
        ">>Detecting OS control device ...  OK\n" +
        ">>Booting ...\n" +
        ">>Processor 0 is Activate ...  OK\n" +
        ">>Processor 1 is Activate ...  OK\n" +
        ">>Processor 2 is Activate ...  OK\n" +
        ">>Processor 3 is Activate ...  OK\n" +
        ">>Memory Initialize [MEM]/32767MBytes\n\n\n\n\n" +
        "INIT: Kernel version 2.04 booting...\n\n\n\n\n" +
        "ROSS:\n\n\n\n\n" +
        "Mounting proc at /proc...<pos=30%>[OK]\n" +
        "Mounting sysfs at /sts...<pos=30%>[OK]\n" +
        "Initakising network<pos=30%>[OK]\n" +
        "Setting up localhost ...<pos=30%>[OK]\n" +
        "Setting up inet1 ...<pos=30%>[OK]\n" +
        "Setting up route ...<pos=30%>[OK]\n" +
        "Accessing Cloud ...<pos=30%>[OK]\n" +
        "Starting system log at /log/sys...<pos=30%>[OK]\n" +
        "Cleaning /var/lock<pos=30%>[OK]\n" +
        "Cleaning /tmp<pos=30%>[OK]\n" +
        "Updating init.rc<pos=30%>[OK]\n\n\n\n\n" +
        "Boot Sequences Start..."

    property int memValue: 0
    property int maxMemory: 32767
    property int visibleChars: 0
    property string displayText: bootLog.replace("[MEM]", "0")

    readonly property real refW: 1920
    readonly property real refH: 1080
    readonly property real scaleX: width  / refW
    readonly property real scaleY: height / refH
    readonly property real sc:    Math.max(0.1, Math.min(scaleX, scaleY))

    FontLoader {
        id: bootFont
        source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/DepartureMono-Regular.otf"
    }

    TextMetrics {
        id: charMetrics
        font.family: bootFont.status === FontLoader.Ready ? bootFont.name : "Courier New"
        font.pixelSize: 18 * sc
        text: "M" // Use wide char for width check if needed, but spaces are usually same in monospace
    }

    function preprocessBootLog(rawLog) {
        var lines = rawLog.split("\n");
        var result = [];
        var charW = charMetrics.advanceWidth;
        if (charW <= 0) charW = 10 * sc; 
        if (charW <= 0) charW = 8; // Absolute fallback

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var posMatch = line.match(/<pos=(\d+)%>/);
            if (posMatch) {
                var percent = parseInt(posMatch[1]);
                var parts = line.split(posMatch[0]);
                var prefix = parts[0];
                var suffix = parts[1];

                // Unity's <pos=30%> is 30% of the text area width
                var targetX = 1920 * (percent / 100.0) * sc;
                var prefixWidth = prefix.length * charW;

                var spacesNeeded = Math.max(1, Math.floor((targetX - prefixWidth) / charW));
                var padding = "";
                for (var j = 0; j < spacesNeeded; j++) padding += " ";
                line = prefix + padding + suffix;
            }
            result.push(line);
        }
        return result.join("\n");
    }

    // Skip logic
    Component.onCompleted: {
        if (AppSettings.getInt("Config_SkipLoading", 0) === 1) {
            Qt.callLater(root.bootFinished);
            return;
        }
        bootTimer.start();
    }

    // ─── Terminal text ───
    Flickable {
        id: termFlick
        anchors.fill: parent
        anchors.leftMargin: 60 * sc
        anchors.topMargin: 70 * sc
        contentHeight: termText.implicitHeight
        clip: true

        Text {
            id: termText
            width: 1920 * sc
            wrapMode: Text.WordWrap
            font.family: bootFont.status === FontLoader.Ready ? bootFont.name : "Courier New"
            font.pixelSize: 18 * sc
            color: "#FF0000"
            text: root.displayText.substring(0, root.visibleChars)
        }
    }

    // ─── Amadeus Logo ───
    Item {
        id: logoPanel
        anchors.centerIn: parent
        visible: false
        opacity: 0

        Image {
            anchors.centerIn: parent
            width: 900 * sc
            height: 900 * sc
            source: "qrc:/qt/qml/RealAmadeusPC/resources/images/amadeus_logo_v3.png"
            fillMode: Image.PreserveAspectFit
        }
    }

    // ─── Sequencer ───
    property var bootLines: []
    property int lineIndex: 0
    property int lineCharPos: 0

    Timer {
        id: bootTimer
        interval: 500  // startDelay
        repeat: false
        onTriggered: {
            root.displayText = preprocessBootLog(root.bootLog);
            root.bootLines = root.displayText.split("\n");
            root.lineIndex = 0;
            root.visibleChars = 0;
            lineAdvanceTimer.interval = 500; // startDelay
            lineAdvanceTimer.restart();
        }
    }

    // Animate line by line
    Timer {
        id: lineAdvanceTimer
        interval: 50
        repeat: true
        onTriggered: {
            if (root.lineIndex >= root.bootLines.length) {
                stop();
                postBootTimer.start();
                return;
            }

            var line = root.bootLines[root.lineIndex];
            var delay = 50;

            // Memory line: animate counter
            if (line.includes("Memory Initialize")) {
                memCounter.start();
                stop();
                return;
            }

            if (line.includes("...") || line.trim() === "") delay = 400;

            // Apply delay to NEXT tick
            lineAdvanceTimer.interval = delay;

            // Advance visible chars by this line's length + newline
            root.visibleChars += line.length + 1;

            // Autoscroll
            termFlick.contentY = Math.max(0, termText.implicitHeight - termFlick.height);

            root.lineIndex++;
        }
    }

    // Memory counter animation
    Timer {
        id: memCounter
        property real elapsed: 0
        property real duration: 1500
        interval: 30
        repeat: true
        onTriggered: {
            elapsed += interval;
            var progress = Math.min(1.0, elapsed / duration);
            root.memValue = Math.floor(progress * root.maxMemory);
            root.displayText = preprocessBootLog(root.bootLog).replace("[MEM]", root.memValue.toString());

            // Find the memory line and advance visibleChars to show it
            var memLineText = ">>Memory Initialize " + root.memValue + "/32767MBytes";
            // Count chars up to and including memory line
            var chars = 0;
            var lines = root.displayText.split("\n");
            for (var i = 0; i <= root.lineIndex && i < lines.length; i++) {
                chars += lines[i].length + 1;
            }
            root.visibleChars = chars;
            termFlick.contentY = Math.max(0, termText.implicitHeight - termFlick.height);

            if (progress >= 1.0) {
                elapsed = 0;
                stop();
                root.lineIndex++;
                Qt.callLater(function() { lineAdvanceTimer.restart(); });
            }
        }
    }

    Timer {
        id: postBootTimer
        interval: 2000
        repeat: false
        onTriggered: {
            termText.visible = false;
            logoPanel.visible = true;
            logoPanel.opacity = 1;
            logoShowTimer.start();
        }
    }

    Timer {
        id: logoShowTimer
        interval: 4000
        repeat: false
        onTriggered: {
            logoPanel.opacity = 0;
            logoPanel.visible = false;
            root.bootFinished();
        }
    }

    Timer {
        id: fadeOutTimer
        interval: 900  // wait for opacity anim
        repeat: false
        onTriggered: {
            root.bootFinished();
        }
    }
}
