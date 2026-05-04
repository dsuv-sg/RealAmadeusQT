import QtQuick 2.15

// ScriptedText: Text-derived component that applies MS Mincho for non-CJK
// characters and Noto Serif CJK fonts for CJK/Hangul runs using <font face=>
// Use by setting `rawText: someString` (supports newlines). Inherit Text props.
Text {
    id: self
    property string rawText: ""
    // Use AppSettings (registered in main.cpp) to pick which Noto variant to prefer
    property int configLanguage: (typeof AppSettings !== 'undefined') ? AppSettings.getInt("Config_Language", 0) : 0
    textFormat: Text.StyledText

    // Force default (non-CJK) glyphs to MS Mincho (or embedded Noto KR) so plain text uses Mincho-style
    font.family: (typeof NotoKRFamily !== 'undefined' && NotoKRFamily ? NotoKRFamily : "MS Mincho")

    // Load Noto CJK fonts from resources (qrc)
    FontLoader { id: notoSC; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKsc-Regular.otf" }
    FontLoader { id: notoTC; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKtc-Regular.otf" }
    FontLoader { id: notoHK; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKhk-Regular.otf" }
    FontLoader { id: notoKR; source: "qrc:/qt/qml/RealAmadeusPC/resources/fonts/NotoSerifCJKkr-Regular.otf" }

    // Exposed family names (updated when loaders are ready)
    property string notoSCFamily: (notoSC.status === FontLoader.Ready ? notoSC.name : (typeof NotoSCFamily !== 'undefined' ? NotoSCFamily : "Noto Serif CJK SC"))
    property string notoTCFamily: (notoTC.status === FontLoader.Ready ? notoTC.name : (typeof NotoTCFamily !== 'undefined' ? NotoTCFamily : "Noto Serif CJK TC"))
    property string notoHKFamily: (notoHK.status === FontLoader.Ready ? notoHK.name : (typeof NotoHKFamily !== 'undefined' ? NotoHKFamily : "Noto Serif CJK HK"))
    property string notoKRFamily: (notoKR.status === FontLoader.Ready ? notoKR.name : (typeof NotoKRFamily !== 'undefined' ? NotoKRFamily : "Noto Serif CJK KR"))

    property bool debugLog: false
    property bool _logged: false

    // Update families when loaders become ready and refresh text
    onNotoSCFamilyChanged: {/* reactive */}
    onNotoTCFamilyChanged: {/* reactive */}
    onNotoHKFamilyChanged: {/* reactive */}
    onNotoKRFamilyChanged: {/* reactive */}

    Component.onCompleted: {
        // If loaders weren't ready initially, attach handlers to update when they become ready.
        if (notoSC.status !== FontLoader.Ready) notoSC.onStatusChanged = function() { if (notoSC.status === FontLoader.Ready) { notoSCFamily = notoSC.name; self.text = makeStyledText(rawText); } }
        if (notoTC.status !== FontLoader.Ready) notoTC.onStatusChanged = function() { if (notoTC.status === FontLoader.Ready) { notoTCFamily = notoTC.name; self.text = makeStyledText(rawText); } }
        if (notoHK.status !== FontLoader.Ready) notoHK.onStatusChanged = function() { if (notoHK.status === FontLoader.Ready) { notoHKFamily = notoHK.name; self.text = makeStyledText(rawText); } }
        if (notoKR.status !== FontLoader.Ready) notoKR.onStatusChanged = function() { if (notoKR.status === FontLoader.Ready) { notoKRFamily = notoKR.name; self.text = makeStyledText(rawText); } }

        // Ensure initial render uses whatever is available
        if (rawText && self.text === "") self.text = makeStyledText(rawText);
    }

    function isHangul(ch) {
        if (!ch) return false;
        var c = ch.charCodeAt(0);
        return (c >= 0xAC00 && c <= 0xD7AF) || (c >= 0x1100 && c <= 0x11FF) || (c >= 0x3130 && c <= 0x318F);
    }
    function isCJK(ch) {
        if (!ch) return false;
        var c = ch.charCodeAt(0);
        return (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) || (c >= 0xF900 && c <= 0xFAFF);
    }

    function faceNameFor(lang) {
        if (lang === 'kr') return notoKRFamily || "Noto Serif CJK KR";
        if (lang === 'tc') return notoTCFamily || "Noto Serif CJK TC";
        if (lang === 'hk') return notoHKFamily || "Noto Serif CJK HK";
        return notoSCFamily || "Noto Serif CJK SC";
    }

    // Choose the CJK Noto variant based on configLanguage.
    // Returns empty string for non-CJK languages → no <font> wrapping → MS Mincho fallback.
    function cjkFaceNameForLang() {
        if (configLanguage === 2) return notoSCFamily || "Noto Serif CJK SC";
        if (configLanguage === 3) return notoKRFamily || "Noto Serif CJK KR";
        return "";
    }

    function makeStyledLine(line) {
        var i = 0;
        var out = "";
        while (i < line.length) {
            var ch = line.charAt(i);
            var run = ch;
            var runIsHangul = isHangul(ch);
            var runIsCJK = isCJK(ch);
            i++;
            while (i < line.length) {
                var next = line.charAt(i);
                if (isHangul(next) !== runIsHangul || isCJK(next) !== runIsCJK) break;
                run += next;
                i++;
            }
            // escape HTML
            var esc = run.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            if (runIsHangul) {
                var face = faceNameFor('kr');
                if (self.debugLog && !self._logged) {
                    console.log("ScriptedText: Hangul face=", face, "notoKRFamily=", notoKRFamily, "notoKR.name=", (notoKR ? notoKR.name : "(no loader)"), "notoKR.status=", (notoKR ? notoKR.status : "(no loader)"));
                    self._logged = true;
                }
                out += '<font face="' + face + '">' + esc + '</font>';
            } else if (runIsCJK) {
                var faceC = cjkFaceNameForLang();
                if (faceC !== "") {
                    if (self.debugLog && !self._logged) { console.log("ScriptedText: CJK face=", faceC); self._logged = true; }
                    out += '<font face="' + faceC + '">' + esc + '</font>';
                } else {
                    // non-CJK language active (e.g. Japanese) → use MS Mincho
                    out += esc;
                }
            } else {
                // non-CJK: rely on Text.font.family (MS Mincho) for Latin/punctuation
                out += esc;
            }
        }
        return out;
    }

    function makeStyledText(src) {
        if (!src) return "";
        var lines = src.split(/\n/);
        for (var i=0;i<lines.length;i++) lines[i] = makeStyledLine(lines[i]);
        return lines.join('<br/>');
    }

    onConfigLanguageChanged: {
        if (rawText) self.text = makeStyledText(rawText);
    }

    onRawTextChanged: {
        self.text = makeStyledText(rawText);
    }
}
