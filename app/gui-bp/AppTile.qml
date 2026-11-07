import QtQuick
import QtQuick.Effects

import "."

// Box art tile. Grows, lifts and gets a ring + glow when focused.
Item {
    id: tile

    property url boxart
    property string name
    property bool running: false
    property bool focused: false

    signal clicked()

    width: Theme.tileWidth
    height: Theme.tileHeight
    z: focused ? 2 : 0

    Item {
        id: body
        anchors.fill: parent
        scale: tile.focused ? Theme.tileFocusScale : 1.0
        transformOrigin: Item.Bottom

        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        // Glow behind the focused tile
        Rectangle {
            id: glowSource
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.accent
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: glowSource
            shadowEnabled: true
            shadowColor: Theme.accent
            shadowBlur: 1.0
            shadowOpacity: tile.focused ? 0.55 : 0.0
            blurMax: 48
            autoPaddingEnabled: true
            opacity: tile.focused ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.surfaceRaised
        }

        Image {
            id: art
            anchors.fill: parent
            source: tile.boxart
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 600
            sourceSize.height: 800
            visible: false
        }

        Rectangle {
            id: mask
            anchors.fill: parent
            radius: Theme.radius
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: art
            maskEnabled: true
            maskSource: mask
            brightness: tile.focused ? 0.0 : -0.15
            Behavior on brightness { NumberAnimation { duration: Theme.animNormal } }
        }

        // Fallback name while box art is loading or missing
        Text {
            anchors.fill: parent
            anchors.margins: Theme.px(16)
            visible: art.status !== Image.Ready
            text: tile.name
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Running indicator
        Rectangle {
            visible: tile.running
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.px(12)
            height: Theme.px(32)
            width: runningRow.implicitWidth + Theme.px(20)
            radius: height / 2
            color: "#CC000000"

            Row {
                id: runningRow
                anchors.centerIn: parent
                spacing: Theme.px(8)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(10)
                    height: width
                    radius: width / 2
                    color: Theme.success
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Running")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                    font.bold: true
                }
            }
        }

        // Focus ring
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.focusBorder - Theme.px(2)
            radius: Theme.radius + Theme.focusBorder
            color: "transparent"
            border.width: Theme.focusBorder
            border.color: Theme.focusRing
            opacity: tile.focused ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tile.clicked()
    }
}
