import QtQuick

import "."

// Pill button. Focus is driven by the owner via `focused`; activation
// arrives through the owner's bpAction(), or by mouse via `clicked`.
Rectangle {
    id: button

    property string text
    property bool focused: false
    property bool destructive: false
    property url icon: ""

    signal clicked()

    implicitWidth: Math.max(Theme.px(200), row.implicitWidth + Theme.px(56))
    implicitHeight: Theme.px(64)
    radius: height / 2

    color: focused ? (destructive ? Theme.danger : Theme.text) : Theme.surfaceRaised
    scale: focused ? 1.05 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.px(12)

        Image {
            visible: button.icon != ""
            source: button.icon
            width: Theme.px(28)
            height: width
            sourceSize.width: width
            sourceSize.height: height
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            color: button.focused ? Theme.background : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.bold: button.focused
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
