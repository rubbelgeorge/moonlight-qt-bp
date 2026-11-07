import QtQuick
import QtQuick.Effects

import "."

// Full-screen ambient background: a heavily blurred, darkened version of the
// focused game's box art that crossfades when the selection changes.
Item {
    id: hero

    property url source: ""

    // Two slots so we can crossfade between the old and the new image
    property int activeSlot: 0

    onSourceChanged: switchTimer.restart()

    // Debounce so fast scrolling through a row doesn't thrash the GPU
    Timer {
        id: switchTimer
        interval: 160
        onTriggered: {
            var next = hero.activeSlot === 0 ? slotB : slotA
            next.source = hero.source
            hero.activeSlot = hero.activeSlot === 0 ? 1 : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.backgroundTop }
            GradientStop { position: 1.0; color: Theme.background }
        }
    }

    component HeroSlot: Item {
        property alias source: img.source
        property bool shown: false

        anchors.fill: parent
        opacity: shown && img.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        Image {
            id: img
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Small decode size: it is blurred anyway
            sourceSize.width: 480
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: img
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.35
            saturation: 0.1
        }
    }

    HeroSlot { id: slotA; shown: hero.activeSlot === 0 }
    HeroSlot { id: slotB; shown: hero.activeSlot === 1 }

    // Vignette so foreground text stays readable
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#99000000" }
            GradientStop { position: 0.35; color: "#33000000" }
            GradientStop { position: 0.75; color: "#AA05060A" }
            GradientStop { position: 1.0; color: "#F205060A" }
        }
    }
}
