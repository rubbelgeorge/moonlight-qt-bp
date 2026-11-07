import QtQuick

import BpInput 1.0
import StreamingPreferences 1.0
import "."

// Renders the button that triggers `action` on the active input device:
// Xbox/PlayStation/Nintendo glyphs for gamepads, key caps for keyboard.
Item {
    id: glyph

    property int action: BpInput.Accept
    property int size: Theme.px(36)

    readonly property string family: BpInput.usingGamepad ? BpInput.controllerFamily : "keyboard"
    readonly property bool isFaceButton: action === BpInput.Accept || action === BpInput.Back ||
                                         action === BpInput.Option || action === BpInput.Secondary

    // Physical face button position (SDL uses positional mapping in Moonlight)
    readonly property string position: {
        var swap = StreamingPreferences.swapFaceButtons
        switch (action) {
        case BpInput.Accept: return swap ? "east" : "south"
        case BpInput.Back: return swap ? "south" : "east"
        case BpInput.Option: return swap ? "north" : "west"
        case BpInput.Secondary: return swap ? "west" : "north"
        }
        return ""
    }

    readonly property var faceLabels: ({
        "xbox":        { "south": "A", "east": "B", "west": "X", "north": "Y" },
        "playstation": { "south": "✕", "east": "○", "west": "□", "north": "△" },
        "nintendo":    { "south": "B", "east": "A", "west": "Y", "north": "X" }
    })

    readonly property var faceColors: ({
        "xbox":        { "south": "#5BC236", "east": "#E5413A", "west": "#3C8DE5", "north": "#F2C230" },
        "playstation": { "south": "#7BA7E8", "east": "#E86B6B", "west": "#E58BC9", "north": "#4FC2A4" },
        "nintendo":    { "south": "#D0D4DC", "east": "#D0D4DC", "west": "#D0D4DC", "north": "#D0D4DC" }
    })

    readonly property string label: {
        if (family === "keyboard") {
            switch (action) {
            case BpInput.Accept: return "Enter"
            case BpInput.Back: return "Esc"
            case BpInput.Option: return "X"
            case BpInput.Secondary: return "Y"
            case BpInput.Menu: return "M"
            case BpInput.View: return "V"
            case BpInput.PrevTab: return "Q"
            case BpInput.NextTab: return "E"
            case BpInput.PageUp: return qsTr("PgUp")
            case BpInput.PageDown: return qsTr("PgDn")
            }
            return "?"
        }

        if (isFaceButton) {
            return faceLabels[family][position]
        }

        var ps = family === "playstation"
        var nin = family === "nintendo"
        switch (action) {
        case BpInput.Menu: return ps ? "OPT" : (nin ? "+" : "≡")
        case BpInput.View: return ps ? "SHR" : (nin ? "−" : "⧉")
        case BpInput.PrevTab: return ps ? "L1" : (nin ? "L" : "LB")
        case BpInput.NextTab: return ps ? "R1" : (nin ? "R" : "RB")
        case BpInput.PageUp: return ps ? "L2" : (nin ? "ZL" : "LT")
        case BpInput.PageDown: return ps ? "R2" : (nin ? "ZR" : "RT")
        }
        return "?"
    }

    readonly property bool round: family !== "keyboard" && isFaceButton
    readonly property color tint: (family !== "keyboard" && isFaceButton) ? faceColors[family][position] : Theme.text

    implicitHeight: size
    implicitWidth: round ? size : Math.max(size, labelText.implicitWidth + Theme.px(18))

    Rectangle {
        anchors.fill: parent
        radius: glyph.round ? width / 2 : Theme.radiusSmall
        color: "transparent"
        border.width: Math.max(2, Theme.px(2.5))
        border.color: glyph.tint
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: glyph.label
        color: glyph.tint
        font.family: Theme.fontFamily
        font.pixelSize: glyph.label.length > 2 ? glyph.size * 0.36 : glyph.size * 0.5
        font.bold: true
    }
}
