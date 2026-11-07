import QtQuick
import QtQuick.Controls

import StreamingPreferences 1.0
import SystemProperties 1.0
import BpInput 1.0
import "."

// Settings: categories on the left, rows on the right.
//   Up/Down   move          Left/Right   change value (or jump to categories)
//   LB/RB     category      A            toggle / open    B   back (saves)
FocusScope {
    id: settings

    property int categoryIndex: 0
    property int rowIndex: 0
    property string zone: "rows"        // "categories" or "rows"

    StackView.onDeactivating: StreamingPreferences.save()
    Component.onDestruction: StreamingPreferences.save()

    // ---- Helpers ----------------------------------------------------------

    function updateDefaultBitrate() {
        if (StreamingPreferences.autoAdjustBitrate) {
            StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                      StreamingPreferences.height,
                                                                                      StreamingPreferences.fps,
                                                                                      StreamingPreferences.enableYUV444)
        }
    }

    function choice(label, options, getter, setter, description) {
        return { "type": "choice", "label": label, "options": options,
                 "get": getter, "set": setter, "description": description || "" }
    }

    function toggle(label, getter, setter, description) {
        return { "type": "toggle", "label": label, "get": getter, "set": setter,
                 "description": description || "" }
    }

    function stepper(label, min, max, step, bigStep, getter, setter, format, description) {
        return { "type": "stepper", "label": label, "min": min, "max": max, "step": step,
                 "bigStep": bigStep, "get": getter, "set": setter, "format": format,
                 "description": description || "" }
    }

    readonly property var resolutions: [
        { "text": "720p", "value": [1280, 720] },
        { "text": "1080p", "value": [1920, 1080] },
        { "text": "1440p", "value": [2560, 1440] },
        { "text": "4K", "value": [3840, 2160] },
        { "text": qsTr("Steam Deck (800p)"), "value": [1280, 800] }
    ]

    readonly property var categories: [
        {
            "title": qsTr("Video"),
            "rows": [
                choice(qsTr("When starting a stream"),
                       [{ "text": qsTr("Ask"), "value": "ask" },
                        { "text": qsTr("This device"), "value": "device" },
                        { "text": qsTr("My settings"), "value": "settings" }],
                       function() { return profiles.mode },
                       function(v) { profiles.mode = v },
                       qsTr("\"This device\" streams at the resolution and refresh rate your screen is set to right now. \"Ask\" also offers your presets.")),
                choice(qsTr("Resolution"), resolutions,
                       function() { return [StreamingPreferences.width, StreamingPreferences.height] },
                       function(v) { StreamingPreferences.width = v[0]; StreamingPreferences.height = v[1]; updateDefaultBitrate() },
                       qsTr("Resolution the host renders and streams at.")),
                choice(qsTr("Frame rate"),
                       [30, 60, 70, 80, 90, 100, 120].map(function(f) { return { "text": f + " FPS", "value": f } }),
                       function() { return StreamingPreferences.fps },
                       function(v) { StreamingPreferences.fps = v; updateDefaultBitrate() }),
                stepper(qsTr("Bitrate"), 500, StreamingPreferences.unlockBitrate ? 500000 : 150000, 1000, 10000,
                        function() { return StreamingPreferences.bitrateKbps },
                        function(v) { StreamingPreferences.bitrateKbps = v; StreamingPreferences.autoAdjustBitrate = false },
                        function(v) { return (v / 1000).toFixed(v < 10000 ? 1 : 0) + " Mbps" },
                        qsTr("Higher looks better but needs a faster network. LT/RT change in bigger steps.")),
                toggle(qsTr("Automatic bitrate"),
                       function() { return StreamingPreferences.autoAdjustBitrate },
                       function(v) { StreamingPreferences.autoAdjustBitrate = v; updateDefaultBitrate() },
                       qsTr("Pick a bitrate based on resolution and frame rate.")),
                choice(qsTr("Display mode"),
                       [{ "text": qsTr("Fullscreen"), "value": StreamingPreferences.WM_FULLSCREEN },
                        { "text": qsTr("Borderless"), "value": StreamingPreferences.WM_FULLSCREEN_DESKTOP },
                        { "text": qsTr("Windowed"), "value": StreamingPreferences.WM_WINDOWED }],
                       function() { return StreamingPreferences.windowMode },
                       function(v) { StreamingPreferences.windowMode = v }),
                toggle(qsTr("V-Sync"),
                       function() { return StreamingPreferences.enableVsync },
                       function(v) { StreamingPreferences.enableVsync = v },
                       qsTr("Prevents tearing, may add a little latency.")),
                toggle(qsTr("Frame pacing"),
                       function() { return StreamingPreferences.framePacing },
                       function(v) { StreamingPreferences.framePacing = v },
                       qsTr("Smoother motion at the cost of a little latency. Requires V-Sync.")),
                choice(qsTr("Video codec"),
                       [{ "text": qsTr("Automatic"), "value": StreamingPreferences.VCC_AUTO },
                        { "text": "H.264", "value": StreamingPreferences.VCC_FORCE_H264 },
                        { "text": "HEVC", "value": StreamingPreferences.VCC_FORCE_HEVC },
                        { "text": "AV1", "value": StreamingPreferences.VCC_FORCE_AV1 }],
                       function() { return StreamingPreferences.videoCodecConfig },
                       function(v) { StreamingPreferences.videoCodecConfig = v }),
                toggle(qsTr("HDR"),
                       function() { return StreamingPreferences.enableHdr },
                       function(v) { StreamingPreferences.enableHdr = v },
                       qsTr("Needs an HDR display and HDR enabled on the host.")),
                choice(qsTr("Video decoder"),
                       [{ "text": qsTr("Automatic"), "value": StreamingPreferences.VDS_AUTO },
                        { "text": qsTr("Hardware"), "value": StreamingPreferences.VDS_FORCE_HARDWARE },
                        { "text": qsTr("Software"), "value": StreamingPreferences.VDS_FORCE_SOFTWARE }],
                       function() { return StreamingPreferences.videoDecoderSelection },
                       function(v) { StreamingPreferences.videoDecoderSelection = v }),
                toggle(qsTr("Performance overlay"),
                       function() { return StreamingPreferences.showPerformanceOverlay },
                       function(v) { StreamingPreferences.showPerformanceOverlay = v })
            ]
        },
        {
            "title": qsTr("Audio"),
            "rows": [
                choice(qsTr("Audio channels"),
                       [{ "text": qsTr("Stereo"), "value": StreamingPreferences.AC_STEREO },
                        { "text": "5.1", "value": StreamingPreferences.AC_51_SURROUND },
                        { "text": "7.1", "value": StreamingPreferences.AC_71_SURROUND }],
                       function() { return StreamingPreferences.audioConfig },
                       function(v) { StreamingPreferences.audioConfig = v }),
                toggle(qsTr("Play audio on host"),
                       function() { return StreamingPreferences.playAudioOnHost },
                       function(v) { StreamingPreferences.playAudioOnHost = v }),
                toggle(qsTr("Mute when Moonlight is in the background"),
                       function() { return StreamingPreferences.muteOnFocusLoss },
                       function(v) { StreamingPreferences.muteOnFocusLoss = v })
            ]
        },
        {
            "title": qsTr("Controller"),
            "rows": [
                toggle(qsTr("Swap A/B and X/Y"),
                       function() { return StreamingPreferences.swapFaceButtons },
                       function(v) { StreamingPreferences.swapFaceButtons = v },
                       qsTr("For Nintendo-style layouts. Applies to this menu and to streaming.")),
                toggle(qsTr("Multiple controllers"),
                       function() { return StreamingPreferences.multiController },
                       function(v) { StreamingPreferences.multiController = v },
                       qsTr("Off: all controllers act as player 1.")),
                toggle(qsTr("Mouse emulation"),
                       function() { return StreamingPreferences.gamepadMouse },
                       function(v) { StreamingPreferences.gamepadMouse = v },
                       qsTr("Hold Start to toggle mouse control with the controller.")),
                toggle(qsTr("Controller input in background"),
                       function() { return StreamingPreferences.backgroundGamepad },
                       function(v) { StreamingPreferences.backgroundGamepad = v }),
                toggle(qsTr("Rumble when moving focus"),
                       function() { return window.hapticsEnabled },
                       function(v) { window.hapticsEnabled = v })
            ]
        },
        {
            "title": qsTr("Host"),
            "rows": [
                toggle(qsTr("Optimize game settings"),
                       function() { return StreamingPreferences.gameOptimizations },
                       function(v) { StreamingPreferences.gameOptimizations = v }),
                toggle(qsTr("Quit game after streaming"),
                       function() { return StreamingPreferences.quitAppAfter },
                       function(v) { StreamingPreferences.quitAppAfter = v }),
                toggle(qsTr("Find PCs automatically"),
                       function() { return StreamingPreferences.enableMdns },
                       function(v) { StreamingPreferences.enableMdns = v }),
                toggle(qsTr("Connection warnings"),
                       function() { return StreamingPreferences.connectionWarnings },
                       function(v) { StreamingPreferences.connectionWarnings = v })
            ]
        }
    ]

    readonly property var currentRows: categories[categoryIndex].rows
    readonly property var currentRow: currentRows[Math.min(rowIndex, currentRows.length - 1)]

    function valueIndex(row) {
        var current = row.get()
        for (var i = 0; i < row.options.length; i++) {
            if (JSON.stringify(row.options[i].value) === JSON.stringify(current)) {
                return i
            }
        }
        return -1
    }

    function displayValue(row) {
        switch (row.type) {
        case "toggle":
            return row.get() ? qsTr("On") : qsTr("Off")
        case "choice":
            var i = valueIndex(row)
            if (i >= 0) return row.options[i].text
            var v = row.get()
            return Array.isArray(v) ? v[0] + "×" + v[1] : String(v)
        case "stepper":
            return row.format(row.get())
        }
        return ""
    }

    function adjust(row, direction, big) {
        switch (row.type) {
        case "toggle":
            row.set(!row.get())
            break
        case "choice":
            var i = valueIndex(row)
            var n = row.options.length
            var next = i < 0 ? 0 : (i + direction + n) % n
            row.set(row.options[next].value)
            break
        case "stepper":
            var step = big ? row.bigStep : row.step
            var value = Math.round((row.get() + direction * step) / step) * step
            row.set(Math.max(row.min, Math.min(row.max, value)))
            break
        }
        window.focusMoved()
    }

    // Saves the current video options as a preset offered when a stream starts
    function savePreset() {
        window.showKeyboard(qsTr("Preset name"), profiles.suggestedPresetName(), function(name) {
            name = name.trim()
            if (name === "") {
                return
            }

            var doSave = function() {
                profiles.savePreset(name)
                window.showMessage(qsTr("Preset saved"),
                                   qsTr("\"%1\" (%2) can now be picked when you start a stream.").arg(name).arg(profiles.describe(null)))
            }

            var exists = profiles.presets.some(function(p) { return p.name === name })
            if (exists) {
                window.showConfirm(qsTr("Replace preset \"%1\"?").arg(name), "", qsTr("Replace"), doSave)
            }
            else {
                doSave()
            }
        })
    }

    function setCategory(index) {
        if (index < 0 || index >= categories.length) {
            return
        }
        categoryIndex = index
        rowIndex = 0
        window.focusMoved()
    }

    function bpAction(action, isRepeat) {
        switch (action) {
        case BpInput.PrevTab:
            setCategory(categoryIndex - 1)
            return true
        case BpInput.NextTab:
            setCategory(categoryIndex + 1)
            return true
        case BpInput.Back:
        case BpInput.Menu:
            if (!isRepeat) stack.pop()
            return true
        case BpInput.Secondary:
            if (!isRepeat) savePreset()
            return true
        }

        if (zone === "save") {
            switch (action) {
            case BpInput.Up:
                zone = "rows"
                window.focusMoved()
                return true
            case BpInput.Accept:
                if (!isRepeat) savePreset()
                return true
            }
            return true
        }

        if (zone === "categories") {
            switch (action) {
            case BpInput.Up: setCategory(categoryIndex - 1); return true
            case BpInput.Down: setCategory(categoryIndex + 1); return true
            case BpInput.Right:
            case BpInput.Accept:
                zone = "rows"
                window.focusMoved()
                return true
            }
            return true
        }

        switch (action) {
        case BpInput.Up:
            if (rowIndex > 0) {
                rowIndex--
                window.focusMoved()
            }
            return true
        case BpInput.Down:
            if (rowIndex < currentRows.length - 1) {
                rowIndex++
            }
            else {
                // Below the last row sits the "Save as preset" button
                zone = "save"
            }
            window.focusMoved()
            return true
        case BpInput.Left:
            if (currentRow.type === "toggle") {
                zone = "categories"
                window.focusMoved()
            }
            else {
                adjust(currentRow, -1, false)
            }
            return true
        case BpInput.Right:
            if (currentRow.type !== "toggle") adjust(currentRow, 1, false)
            return true
        case BpInput.PageUp:
            if (currentRow.type === "stepper") adjust(currentRow, -1, true)
            return true
        case BpInput.PageDown:
            if (currentRow.type === "stepper") adjust(currentRow, 1, true)
            return true
        case BpInput.Accept:
            if (!isRepeat) adjust(currentRow, 1, false)
            return true
        }
        return true
    }

    // ---- Layout -------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.85
    }

    Text {
        id: header
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Theme.margin
        anchors.topMargin: Theme.px(48)
        text: qsTr("Settings")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitle
        font.bold: true
    }

    Column {
        id: categoryColumn
        anchors.left: parent.left
        anchors.top: header.bottom
        anchors.leftMargin: Theme.margin
        anchors.topMargin: Theme.px(48)
        width: Theme.px(360)
        spacing: Theme.px(8)

        Repeater {
            model: settings.categories

            Rectangle {
                readonly property bool selected: index === settings.categoryIndex
                readonly property bool focused: selected && settings.zone === "categories"

                width: categoryColumn.width
                height: Theme.px(68)
                radius: Theme.radiusSmall
                color: focused ? Theme.text : (selected ? Theme.surfaceRaised : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Rectangle {
                    visible: parent.selected && !parent.focused
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(4)
                    height: parent.height * 0.5
                    radius: width / 2
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.px(24)
                    text: modelData.title
                    color: parent.focused ? Theme.background : (parent.selected ? Theme.text : Theme.textDim)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.bold: parent.selected
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: settings.setCategory(index)
                }
            }
        }
    }

    ListView {
        id: rowList
        anchors.left: categoryColumn.right
        anchors.right: parent.right
        anchors.top: categoryColumn.top
        anchors.bottom: descriptionText.top
        anchors.leftMargin: Theme.px(64)
        anchors.rightMargin: Theme.margin
        anchors.bottomMargin: Theme.px(24)
        clip: true
        spacing: Theme.px(8)
        keyNavigationEnabled: false
        model: settings.currentRows
        currentIndex: settings.rowIndex
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: height * 0.25
        preferredHighlightEnd: height * 0.75
        highlightMoveDuration: Theme.animNormal

        delegate: Rectangle {
            readonly property bool focused: index === settings.rowIndex && settings.zone === "rows"
            readonly property var row: modelData

            width: rowList.width
            height: Theme.px(80)
            radius: Theme.radiusSmall
            color: focused ? Theme.surfaceFocused : Theme.surface
            border.width: focused ? Theme.px(3) : 0
            border.color: Theme.focusRing
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.px(32)
                anchors.right: valueRow.left
                anchors.rightMargin: Theme.px(24)
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                elide: Text.ElideRight
            }

            Row {
                id: valueRow
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(32)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.px(16)

                // Toggle switch
                Rectangle {
                    visible: row.type === "toggle"
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(72)
                    height: Theme.px(40)
                    radius: height / 2
                    color: row.type === "toggle" && row.get() ? Theme.accent : Theme.surfaceRaised
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Rectangle {
                        width: parent.height - Theme.px(8)
                        height: width
                        radius: width / 2
                        y: Theme.px(4)
                        x: row.type === "toggle" && row.get() ? parent.width - width - Theme.px(4) : Theme.px(4)
                        color: Theme.text
                        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    }
                }

                // Choice / stepper: ‹ value ›
                Text {
                    visible: row.type !== "toggle"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    color: parent.parent.focused ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.fontHeading
                }
                Text {
                    visible: row.type !== "toggle"
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(220)
                    horizontalAlignment: Text.AlignHCenter
                    text: settings.displayValue(row)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.bold: parent.parent.focused
                }
                Text {
                    visible: row.type !== "toggle"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: parent.parent.focused ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.fontHeading
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    settings.zone = "rows"
                    settings.rowIndex = index
                    settings.adjust(row, 1, false)
                }
            }
        }
    }

    Text {
        id: descriptionText
        anchors.left: rowList.left
        anchors.right: rowList.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.px(24)
        height: Theme.px(64)
        text: settings.zone === "rows" && settings.currentRow ? settings.currentRow.description : ""
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.Wrap
    }

    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        anchors.bottomMargin: Theme.px(36)
        height: Theme.px(64)

        BpButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Save as preset")
            focused: settings.zone === "save"
            onClicked: settings.savePreset()
        }

        ButtonHintBar {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            hints: settings.zone === "save"
                   ? [{ "action": BpInput.Accept, "text": qsTr("Save as preset") },
                      { "action": BpInput.Back, "text": qsTr("Back") }]
                   : [{ "action": BpInput.Accept, "text": qsTr("Change") },
                      { "action": BpInput.Secondary, "text": qsTr("Save as preset") },
                      { "action": BpInput.NextTab, "text": qsTr("Category") },
                      { "action": BpInput.Back, "text": qsTr("Back") }]
        }
    }
}
