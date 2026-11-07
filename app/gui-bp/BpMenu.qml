import QtQuick

import BpInput 1.0
import "."

// Context menu that slides in from the right edge.
BpModal {
    id: menu

    property string title
    property var items: []          // [{ text, action, destructive }]
    property int currentIndex: 0

    function activate(index) {
        var item = items[index]
        close()
        if (item && typeof item.action === "function") {
            item.action()
        }
    }

    function bpAction(action, isRepeat) {
        switch (action) {
        case BpInput.Up:
            if (currentIndex > 0) {
                currentIndex--
                window.focusMoved()
            }
            return true
        case BpInput.Down:
            if (currentIndex < items.length - 1) {
                currentIndex++
                window.focusMoved()
            }
            return true
        case BpInput.Accept:
            if (!isRepeat) {
                activate(currentIndex)
            }
            return true
        case BpInput.Back:
        case BpInput.Option:
        case BpInput.Menu:
            if (!isRepeat) {
                close()
            }
            return true
        }
        return true
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.min(Theme.px(620), parent.width * 0.6)
        x: parent.width - width * (menu.closing ? 0 : menu.appear)
        color: Theme.surface

        Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Theme.margin
            anchors.leftMargin: Theme.px(48)
            anchors.rightMargin: Theme.px(48)
            spacing: Theme.px(10)

            Text {
                width: parent.width
                text: menu.title
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.px(2)
                elide: Text.ElideRight
                bottomPadding: Theme.px(18)
            }

            Repeater {
                model: menu.items

                Rectangle {
                    readonly property bool focused: index === menu.currentIndex

                    width: parent.width
                    height: Theme.px(72)
                    radius: Theme.radiusSmall
                    color: focused ? Theme.text : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.px(24)
                        text: modelData.text
                        color: parent.focused ? Theme.background
                                              : (modelData.destructive ? Theme.danger : Theme.text)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: parent.focused
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: menu.activate(index)
                    }
                }
            }
        }

        ButtonHintBar {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.px(48)
            hints: [
                { "action": BpInput.Accept, "text": qsTr("Select") },
                { "action": BpInput.Back, "text": qsTr("Close") }
            ]
        }
    }
}
