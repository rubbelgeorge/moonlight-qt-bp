import QtQuick

import BpInput 1.0
import "."

// Centered message box with a horizontal row of buttons.
BpModal {
    id: dialog

    property string title
    property string text
    property var buttons: []       // [{ text, action, destructive }]
    property bool cancelable: true
    property bool busy: false
    property string highlight: ""
    property int currentIndex: 0

    function activate(index) {
        var button = buttons[index]
        close()
        if (button && typeof button.action === "function") {
            button.action()
        }
    }

    function bpAction(action, isRepeat) {
        switch (action) {
        case BpInput.Left:
            if (currentIndex > 0) {
                currentIndex--
                window.focusMoved()
            }
            return true
        case BpInput.Right:
            if (currentIndex < buttons.length - 1) {
                currentIndex++
                window.focusMoved()
            }
            return true
        case BpInput.Accept:
            if (!isRepeat && buttons.length > 0) {
                activate(currentIndex)
            }
            return true
        case BpInput.Back:
            if (cancelable && !isRepeat) {
                close()
            }
            return true
        }
        // Modal: swallow everything else
        return true
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.margin * 2, Theme.px(1000))
        height: content.implicitHeight + Theme.px(96)
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.surfaceRaised
        border.width: 1

        scale: dialog.closing ? 0.96 : (0.94 + 0.06 * dialog.appear)
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.px(48)
            spacing: Theme.px(28)

            Text {
                width: parent.width
                visible: dialog.title !== ""
                text: dialog.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.bold: true
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                visible: dialog.text !== ""
                text: dialog.text
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }

            // Large emphasized value, e.g. a pairing PIN
            Text {
                visible: dialog.highlight !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: dialog.highlight
                color: Theme.accentStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.px(96)
                font.bold: true
                font.letterSpacing: Theme.px(18)
            }

            BusyDots {
                visible: dialog.busy
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                visible: dialog.buttons.length > 0
                spacing: Theme.spacing
                anchors.right: parent.right

                Repeater {
                    model: dialog.buttons

                    BpButton {
                        text: modelData.text
                        destructive: !!modelData.destructive
                        focused: index === dialog.currentIndex
                        onClicked: dialog.activate(index)
                    }
                }
            }
        }
    }
}
