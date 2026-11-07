pragma Singleton
import QtQuick

// Design tokens for the Big Picture UI.
// Everything is designed at 1920x1080 and scaled by `scale`
// (set by BigPicture.qml whenever the window size changes).
QtObject {
    property real scale: 1.0

    function px(v) { return Math.round(v * scale) }

    // Colors
    readonly property color background: "#0A0C12"
    readonly property color backgroundTop: "#151A2B"
    readonly property color surface: "#171B26"
    readonly property color surfaceRaised: "#222838"
    readonly property color surfaceFocused: "#2E3650"
    readonly property color accent: "#8C9BFF"
    readonly property color accentStrong: "#B3BDFF"
    readonly property color text: "#F2F4F8"
    readonly property color textDim: "#9AA3B8"
    readonly property color textMuted: "#5E667A"
    readonly property color focusRing: "#FFFFFF"
    readonly property color success: "#5BD68A"
    readonly property color warning: "#FFC857"
    readonly property color danger: "#FF6B6B"
    readonly property color scrim: "#CC05060A"

    // Typography (pixel sizes at 1080p)
    readonly property string fontFamily: Qt.application.font.family
    readonly property int fontHero: px(56)
    readonly property int fontTitle: px(40)
    readonly property int fontHeading: px(30)
    readonly property int fontBody: px(24)
    readonly property int fontSmall: px(20)
    readonly property int fontTiny: px(16)

    // Geometry
    readonly property int margin: px(72)
    readonly property int spacing: px(24)
    readonly property int radius: px(14)
    readonly property int radiusSmall: px(8)
    readonly property int focusBorder: px(4)

    // App tiles use the standard 600x800 box art ratio
    readonly property int tileWidth: px(240)
    readonly property int tileHeight: px(320)
    readonly property real tileFocusScale: 1.12

    // Motion
    readonly property int animFast: 120
    readonly property int animNormal: 200
    readonly property int animSlow: 350
}
