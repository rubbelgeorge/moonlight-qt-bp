import QtQuick

import BpInput 1.0
import "."

// Asked before every stream: device mode, own settings, or a saved preset.
//   A: start with the focused profile   X: delete preset   B: cancel
BpModal {
    id: picker

    property string appName
    property var profiles: null
    property var acceptedFn: null
    property var options: profiles ? profiles.pickerOptions() : []
    property int currentIndex: 0

    Component.onCompleted: {
        // Start on the profile used last time
        for (var i = 0; i < options.length; i++) {
            if (options[i].key === profiles.lastChoice) {
                currentIndex = i
                break
            }
        }
    }

    function activate(index) {
        var key = options[index].key
        var fn = acceptedFn
        close()
        if (typeof fn === "function") {
            fn(key)
        }
    }

    function deleteFocused() {
        var option = options[currentIndex]
        if (!option.deletable) {
            return
        }
        var name = option.title
        window.showConfirm(qsTr("Delete preset \"%1\"?").arg(name), option.detail, qsTr("Delete"), function() {
            profiles.deletePreset(name)
            var newOptions = profiles.pickerOptions()
            currentIndex = Math.min(currentIndex, newOptions.length - 1)
            options = newOptions
        }, true)
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
            if (currentIndex < options.length - 1) {
                currentIndex++
                window.focusMoved()
            }
            return true
        case BpInput.Accept:
            if (!isRepeat) activate(currentIndex)
            return true
        case BpInput.Option:
            if (!isRepeat) deleteFocused()
            return true
        case BpInput.Back:
            if (!isRepeat) close()
            return true
        }
        return true
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.margin * 2, Theme.px(900))
        height: Math.min(parent.height - Theme.px(96), content.implicitHeight + Theme.px(96))
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.surfaceRaised
        border.width: 1

        scale: picker.closing ? 0.96 : (0.94 + 0.06 * picker.appear)
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.px(48)
            spacing: Theme.px(24)

            Column {
                width: parent.width
                spacing: Theme.px(6)

                Text {
                    width: parent.width
                    text: qsTr("Start %1").arg(picker.appName)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: qsTr("Which resolution and frame rate should this stream use?")
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.Wrap
                }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, panel.parent.height - Theme.px(420))
                clip: true
                spacing: Theme.px(10)
                interactive: contentHeight > height
                keyNavigationEnabled: false
                model: picker.options
                currentIndex: picker.currentIndex
                highlightMoveDuration: Theme.animFast

                delegate: Rectangle {
                    readonly property bool focused: index === picker.currentIndex

                    width: list.width
                    height: Theme.px(96)
                    radius: Theme.radiusSmall
                    color: focused ? Theme.text : Theme.surfaceRaised
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.px(28)
                        anchors.rightMargin: Theme.px(28)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.px(4)

                        Text {
                            width: parent.width
                            text: modelData.title
                            color: focused ? Theme.background : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.detail
                            color: focused ? Theme.surfaceFocused : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: picker.activate(index)
                    }
                }
            }

            ButtonHintBar {
                anchors.right: parent.right
                hints: {
                    var h = [{ "action": BpInput.Accept, "text": qsTr("Start") }]
                    var focusedOption = picker.options[picker.currentIndex]
                    if (focusedOption && focusedOption.deletable) {
                        h.push({ "action": BpInput.Option, "text": qsTr("Delete preset") })
                    }
                    h.push({ "action": BpInput.Back, "text": qsTr("Cancel") })
                    return h
                }
            }
        }
    }
}
