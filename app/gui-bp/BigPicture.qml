import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtCore

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import BpInput 1.0
import "."

// Root of the Big Picture UI.
//
// Input model: gamepad (BpInput.action) and keyboard (Keys -> BpInput.actionForKey)
// both end up in dispatch(), which walks from the active focus item up the
// parent chain and calls `bpAction(action, isRepeat)` on every item that
// defines it, until one returns true. Pages and modals only implement
// bpAction(); none of them use Keys handlers.
Window {
    id: window

    property bool pollingActive: false
    property url heroSource: ""
    property bool hapticsEnabled: false

    width: 1600
    height: 900
    minimumWidth: 960
    minimumHeight: 540
    color: Theme.background
    title: "Moonlight"

    // Resolution/frame rate profiles chosen when a stream starts
    StreamProfiles {
        id: profiles
        hostWindow: window
    }

    // Big Picture-only preferences
    Settings {
        category: "BigPicture"
        property alias hapticsEnabled: window.hapticsEnabled
        property alias streamProfileMode: profiles.mode
        property alias streamPresets: profiles.presetsJson
        property alias lastStreamProfile: profiles.lastChoice
    }

    function updateScale() {
        Theme.scale = Math.min(width / 1920, height / 1080)
    }
    onWidthChanged: updateScale()
    onHeightChanged: updateScale()

    Component.onCompleted: {
        updateScale()

        // A console UI is fullscreen. F11 toggles windowed mode for testing.
        window.showFullScreen()

        BpInput.enable()

        SystemProperties.hasHardwareAccelerationChanged.connect(function() {
            if (!SystemProperties.hasHardwareAcceleration &&
                    StreamingPreferences.videoDecoderSelection !== StreamingPreferences.VDS_FORCE_SOFTWARE) {
                showMessage(qsTr("No hardware video decoding"),
                            qsTr("Your system doesn't support hardware video decoding. Streaming performance may be very poor. Make sure your GPU drivers are up to date."))
            }
        })
        SystemProperties.startAsyncLoad()
    }

    // ---- Input dispatch -------------------------------------------------

    function dispatch(action, isRepeat) {
        var item = window.activeFocusItem
        while (item) {
            if (typeof item.bpAction === "function" && item.bpAction(action, isRepeat)) {
                return true
            }
            item = item.parent
        }
        return false
    }

    // Called by components whenever the focus visibly moves
    function focusMoved() {
        if (hapticsEnabled && BpInput.usingGamepad) {
            BpInput.rumbleTick()
        }
    }

    Connections {
        target: BpInput
        function onAction(action, isRepeat) {
            window.dispatch(action, isRepeat)
        }
    }

    // ---- Modal helpers --------------------------------------------------

    function openModal(component, props) {
        var previousFocus = window.activeFocusItem
        var modal = component.createObject(modalLayer, props || {})
        if (modal === null) {
            console.error("Failed to create modal: " + component.errorString())
            return null
        }
        modal.closed.connect(function() {
            if (previousFocus && previousFocus.visible) {
                previousFocus.forceActiveFocus()
            }
            else if (stack.currentItem) {
                stack.currentItem.forceActiveFocus()
            }
            modal.destroy(Theme.animNormal + 50)
        })
        modal.forceActiveFocus()
        return modal
    }

    // buttons: [{ text, action: function, destructive }]
    function showDialog(title, text, buttons, cancelable) {
        return openModal(dialogComponent, {
            "title": title,
            "text": text,
            "buttons": buttons || [{ "text": qsTr("OK") }],
            "cancelable": cancelable === undefined ? true : cancelable
        })
    }

    function showMessage(title, text) {
        return showDialog(title, text, [{ "text": qsTr("OK") }], true)
    }

    function showConfirm(title, text, confirmText, onConfirm, destructive) {
        return openModal(dialogComponent, {
            "title": title,
            "text": text,
            "buttons": [
                { "text": confirmText, "action": onConfirm, "destructive": !!destructive },
                { "text": qsTr("Cancel") }
            ],
            "cancelable": true,
            // Destructive actions start on "Cancel" so a double press can't trigger them
            "currentIndex": destructive ? 1 : 0
        })
    }

    // Non-cancelable dialog with a spinner. Call .close() on the result.
    function showBusy(title, text) {
        return openModal(dialogComponent, {
            "title": title,
            "text": text || "",
            "buttons": [],
            "cancelable": false,
            "busy": true
        })
    }

    // Dialog with a big highlighted value (pairing PIN) and a spinner
    function showPin(title, text, pin) {
        return openModal(dialogComponent, {
            "title": title,
            "text": text,
            "highlight": pin,
            "buttons": [{ "text": qsTr("Hide") }],
            "cancelable": true,
            "busy": true
        })
    }

    // items: [{ text, action: function, destructive }]
    function showMenu(title, items) {
        return openModal(menuComponent, { "title": title, "items": items })
    }

    // onAccepted(text) is called with the entered text
    function showKeyboard(title, initialText, onAccepted, placeholder) {
        return openModal(keyboardComponent, {
            "title": title,
            "text": initialText || "",
            "placeholder": placeholder || "",
            "acceptedFn": onAccepted
        })
    }

    Component { id: dialogComponent; BpDialog {} }
    Component { id: menuComponent; BpMenu {} }
    Component { id: keyboardComponent; OnScreenKeyboard {} }

    // ---- Host polling (same lifecycle as the desktop UI) ----------------

    Timer {
        id: inactivityTimer
        interval: 5 * 60000
        onTriggered: {
            if (!window.active && window.pollingActive) {
                ComputerManager.stopPollingAsync()
                window.pollingActive = false
            }
        }
    }

    onVisibleChanged: {
        if (!visible) {
            inactivityTimer.stop()
            if (pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
        else if (active) {
            inactivityTimer.stop()
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }

        BpInput.notifyWindowFocus(visible && active)
    }

    onActiveChanged: {
        if (active) {
            inactivityTimer.stop()
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }
        else {
            inactivityTimer.restart()
        }

        BpInput.notifyWindowFocus(visible && active)
    }

    // ---- Visual tree ------------------------------------------------------

    FocusScope {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_F11) {
                if (window.visibility === Window.FullScreen) {
                    window.showNormal()
                }
                else {
                    window.showFullScreen()
                }
                event.accepted = true
                return
            }

            // Text entry (on-screen keyboard) gets raw key events first
            for (var item = window.activeFocusItem; item; item = item.parent) {
                if (typeof item.bpKeyInput === "function") {
                    if (item.bpKeyInput(event)) {
                        BpInput.notifyKeyboardUsed()
                        event.accepted = true
                        return
                    }
                    break
                }
            }

            var action = BpInput.actionForKey(event.key)
            if (action !== BpInput.None) {
                BpInput.notifyKeyboardUsed()
                window.dispatch(action, event.isAutoRepeat)
                event.accepted = true
            }
        }

        HeroBackground {
            anchors.fill: parent
            source: window.heroSource
        }

        StackView {
            id: stack
            anchors.fill: parent
            focus: true

            initialItem: HomeView {}

            onCurrentItemChanged: {
                if (currentItem) {
                    currentItem.forceActiveFocus()
                }
            }

            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 1.04; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
                }
            }
            pushExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animNormal }
            }
            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.animSlow; easing.type: Easing.OutCubic }
                }
            }
            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animNormal }
                    NumberAnimation { property: "scale"; from: 1; to: 1.04; duration: Theme.animNormal }
                }
            }
            replaceEnter: pushEnter
            replaceExit: pushExit
        }

        Item {
            id: modalLayer
            anchors.fill: parent
        }
    }
}
