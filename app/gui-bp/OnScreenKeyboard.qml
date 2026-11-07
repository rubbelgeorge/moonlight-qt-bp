import QtQuick

import BpInput 1.0
import "."

// Gamepad-driven on-screen keyboard.
//   D-pad/stick: move   A: type key   B: close (or backspace if text)
//   X: backspace        Y: space      LB/RB: cursor-free shift toggle / symbols
//   Start: done
BpModal {
    id: osk

    property string title
    property string text
    property string placeholder
    property var acceptedFn: null

    property bool shifted: false
    property bool symbols: false
    property int row: 1
    property int col: 0

    readonly property var letterRows: [
        "1234567890".split(""),
        "qwertyuiop".split(""),
        "asdfghjkl-".split(""),
        ["⇧"].concat("zxcvbnm.:".split(""))
    ]
    readonly property var symbolRows: [
        "1234567890".split(""),
        "!@#$%&*()/".split(""),
        ";_+=?'\"[]~".split(""),
        ["⇧"].concat(",<>{}|\\^`".split(""))
    ]
    readonly property var bottomRow: [
        { "label": symbols ? "abc" : "?123", "key": "mode", "w": 2 },
        { "label": qsTr("Space"), "key": " ", "w": 4 },
        { "label": "⌫", "key": "backspace", "w": 2 },
        { "label": qsTr("Done"), "key": "done", "w": 2 }
    ]

    // Every row is an array of { label, key, w } with w in key units (10 per row)
    readonly property var rows: {
        var src = symbols ? symbolRows : letterRows
        var result = []
        for (var r = 0; r < src.length; r++) {
            var keys = []
            for (var c = 0; c < src[r].length; c++) {
                var ch = src[r][c]
                if (ch === "⇧") {
                    keys.push({ "label": ch, "key": "shift", "w": 1 })
                }
                else {
                    var shown = shifted && !symbols ? ch.toUpperCase() : ch
                    keys.push({ "label": shown, "key": shown, "w": 1 })
                }
            }
            result.push(keys)
        }
        result.push(bottomRow)
        return result
    }

    function keyCenter(r, c) {
        var x = 0
        for (var i = 0; i < c; i++) {
            x += rows[r][i].w
        }
        return x + rows[r][c].w / 2
    }

    function nearestCol(r, center) {
        var best = 0, bestDist = 1e9, x = 0
        for (var i = 0; i < rows[r].length; i++) {
            var d = Math.abs(x + rows[r][i].w / 2 - center)
            if (d < bestDist) {
                bestDist = d
                best = i
            }
            x += rows[r][i].w
        }
        return best
    }

    function press(key) {
        switch (key) {
        case "shift": shifted = !shifted; break
        case "mode": symbols = !symbols; col = Math.min(col, rows[row].length - 1); break
        case "backspace": text = text.slice(0, -1); break
        case "done": finish(); break
        default:
            text += key
            // One-shot shift like a phone keyboard
            if (shifted) {
                shifted = false
            }
            break
        }
    }

    function finish() {
        var fn = acceptedFn
        var value = text
        close()
        if (typeof fn === "function") {
            fn(value)
        }
    }

    // Physical keyboard typing goes straight into the field
    function bpKeyInput(event) {
        if (event.key === Qt.Key_Backspace) {
            press("backspace")
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            finish()
            return true
        }
        if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 &&
                !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            text += event.text
            return true
        }
        return false
    }

    function bpAction(action, isRepeat) {
        switch (action) {
        case BpInput.Up:
            if (row > 0) {
                var cu = keyCenter(row, col)
                row--
                col = nearestCol(row, cu)
                window.focusMoved()
            }
            return true
        case BpInput.Down:
            if (row < rows.length - 1) {
                var cd = keyCenter(row, col)
                row++
                col = nearestCol(row, cd)
                window.focusMoved()
            }
            return true
        case BpInput.Left:
            col = (col - 1 + rows[row].length) % rows[row].length
            window.focusMoved()
            return true
        case BpInput.Right:
            col = (col + 1) % rows[row].length
            window.focusMoved()
            return true
        case BpInput.Accept:
            press(rows[row][col].key)
            return true
        case BpInput.Option:
            press("backspace")
            return true
        case BpInput.Secondary:
            press(" ")
            return true
        case BpInput.PrevTab:
            if (!isRepeat) press("shift")
            return true
        case BpInput.NextTab:
            if (!isRepeat) press("mode")
            return true
        case BpInput.Menu:
            if (!isRepeat) finish()
            return true
        case BpInput.Back:
            if (!isRepeat) close()
            return true
        }
        return true
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Theme.margin * 2, Theme.px(1240))
        height: column.implicitHeight + Theme.px(80)
        y: parent.height - (height + Theme.margin) * (osk.closing ? 0 : osk.appear)
        radius: Theme.radius
        color: Theme.surface

        Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.px(40)
            spacing: Theme.px(16)

            Text {
                text: osk.title
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
            }

            // Text field
            Rectangle {
                width: parent.width
                height: Theme.px(80)
                radius: Theme.radiusSmall
                color: Theme.background
                border.color: Theme.accent
                border.width: Theme.px(2)

                Text {
                    id: fieldText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(24)
                    text: osk.text !== "" ? osk.text : osk.placeholder
                    color: osk.text !== "" ? Theme.text : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeading
                }

                // Caret
                Rectangle {
                    x: osk.text !== "" ? fieldText.x + fieldText.contentWidth + Theme.px(4) : fieldText.x
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(3)
                    height: Theme.px(40)
                    color: Theme.accent

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }

            Item { width: 1; height: Theme.px(4) }

            Repeater {
                model: osk.rows

                Row {
                    id: keyRow
                    readonly property int rowIndex: index
                    readonly property real unit: (column.width - Theme.px(8) * 9) / 10

                    spacing: Theme.px(8)

                    Repeater {
                        model: modelData

                        Rectangle {
                            readonly property bool focused: keyRow.rowIndex === osk.row && index === osk.col
                            readonly property bool active: (modelData.key === "shift" && osk.shifted)

                            width: keyRow.unit * modelData.w + Theme.px(8) * (modelData.w - 1)
                            height: Theme.px(68)
                            radius: Theme.radiusSmall
                            color: focused ? Theme.text : (active ? Theme.surfaceFocused : Theme.surfaceRaised)
                            scale: focused ? 1.08 : 1.0
                            z: focused ? 1 : 0

                            Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.focused ? Theme.background : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: modelData.w > 1 ? Theme.fontSmall : Theme.fontBody
                                font.bold: parent.focused
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    osk.row = keyRow.rowIndex
                                    osk.col = index
                                    osk.press(modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            ButtonHintBar {
                anchors.right: parent.right
                hints: [
                    { "action": BpInput.Option, "text": qsTr("Delete") },
                    { "action": BpInput.Secondary, "text": qsTr("Space") },
                    { "action": BpInput.PrevTab, "text": qsTr("Shift") },
                    { "action": BpInput.Menu, "text": qsTr("Done") },
                    { "action": BpInput.Back, "text": qsTr("Cancel") }
                ]
            }
        }
    }
}
