import QtQuick

/// FadePanel - generic fade wrapper used by sub-panels
Item {
    id: root
    property real fadeDuration: 250
    property alias content: loader.sourceComponent

    Loader { id: loader; anchors.fill: parent }

    function fadeIn()  { fadeAnim.to = 1; fadeAnim.start(); }
    function fadeOut() { fadeAnim.to = 0; fadeAnim.start(); }

    opacity: 0
    NumberAnimation { id: fadeAnim; target: root; property: "opacity"; duration: root.fadeDuration }
}
