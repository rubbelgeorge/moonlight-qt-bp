import QtQuick
import QtQuick.Effects

import "."

// Pill in the top bar: a host (with status dot), "+" or the settings icon.
Rectangle {
    id: tab

    property string label
    property string tooltip
    property url icon: ""
    property color statusColor: "transparent"
    property bool selected: false
    property bool focused: false

    readonly property bool hasIcon: icon != ""

    signal clicked()

    implicitHeight: Theme.px(60)
    implicitWidth: hasIcon || label.length <= 1 ? implicitHeight
                                                : row.implicitWidth + Theme.px(48)
    radius: height / 2

    color: focused ? Theme.text : (selected ? Theme.surfaceFocused : "transparent")
    border.width: !focused && !selected ? Math.max(1, Theme.px(2)) : 0
    border.color: Theme.surfaceRaised
    scale: focused ? 1.06 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }

    Row {
        id: row
        visible: !tab.hasIcon
        anchors.centerIn: parent
        spacing: Theme.px(12)

        Rectangle {
            visible: tab.statusColor != "transparent"
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(12)
            height: width
            radius: width / 2
            color: tab.statusColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tab.label
            color: tab.focused ? Theme.background : (tab.selected ? Theme.text : Theme.textDim)
            font.family: Theme.fontFamily
            font.pixelSize: tab.label.length <= 1 ? Theme.fontHeading : Theme.fontBody
            font.bold: tab.selected || tab.focused
        }
    }

    // Icons are white SVGs; tint them dark on the white focused pill
    Image {
        id: iconImage
        visible: false
        source: tab.icon
        width: Theme.px(32)
        height: width
        sourceSize.width: width
        sourceSize.height: height
    }

    MultiEffect {
        visible: tab.hasIcon
        anchors.centerIn: parent
        width: iconImage.width
        height: iconImage.height
        source: iconImage
        colorization: tab.focused ? 1.0 : 0.0
        colorizationColor: Theme.background
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tab.clicked()
    }
}
