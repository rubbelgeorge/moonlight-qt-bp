import QtQuick

import "."

// Base for every overlay (dialogs, menus, keyboard). Created via
// window.openModal(), which restores focus and destroys it after close().
FocusScope {
    id: modal

    signal closed()

    property bool closing: false
    property real appear: 0

    anchors.fill: parent
    z: 1

    function close() {
        if (closing) {
            return
        }
        closing = true
        closed()
    }

    Component.onCompleted: appear = 1
    opacity: closing ? 0 : appear
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }

    // Swallow mouse input below the overlay
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => { wheel.accepted = true }
    }
}
