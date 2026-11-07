import QtQuick

import "."

// Three pulsing dots, used as a lightweight busy indicator
Row {
    id: dots

    property color color: Theme.accent
    property int dotSize: Theme.px(16)
    property bool running: visible

    spacing: dotSize * 0.75

    Repeater {
        model: 3

        Rectangle {
            width: dots.dotSize
            height: width
            radius: width / 2
            color: dots.color
            opacity: 0.25

            SequentialAnimation on opacity {
                running: dots.running
                loops: Animation.Infinite
                PauseAnimation { duration: index * 160 }
                NumberAnimation { to: 1.0; duration: 320; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0.25; duration: 480; easing.type: Easing.InQuad }
                PauseAnimation { duration: (2 - index) * 160 }
            }
        }
    }
}
