// Eine Blockkachel -- fuer geplante wie fuer bestaetigte Bloecke dieselbe.
//
// Der raeumliche Eindruck entsteht aus drei Lagen: eine dunkle Rueckflaeche,
// die rechts und unten hervorschaut, die eingefaerbte Vorderflaeche und
// darueber ein Glanz. Der Glanz macht den Glaseindruck: hell und schraeg
// ueber die obere Haelfte, dazu eine helle Kante oben und eine dunkle unten.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    property color tone: "#7b5cd6"
    property bool highlighted: false
    property bool hovered: false
    property real depth: 6
    property real cornerRadius: 4
    // Die Vorderflaeche -- Inhalte werden hier hineingehaengt
    default property alias content: face.data

    readonly property real faceWidth: width - depth
    readonly property real faceHeight: height - depth

    readonly property color base: hovered ? Qt.lighter(tone, 1.2)
                                          : (highlighted ? Qt.lighter(tone, 1.08) : tone)

    // --- Rueckflaeche: gibt die Tiefe -----------------------------------
    Rectangle {
        anchors.fill: face
        anchors.leftMargin: -root.depth * 0.35
        anchors.topMargin: -root.depth * 0.35
        anchors.rightMargin: -root.depth
        anchors.bottomMargin: -root.depth
        radius: root.cornerRadius
        color: Qt.darker(root.base, 2.6)
        opacity: 0.9
    }

    // --- Vorderflaeche ---------------------------------------------------
    Rectangle {
        id: face

        anchors.left: parent.left
        anchors.top: parent.top
        width: root.faceWidth
        height: root.faceHeight
        radius: root.cornerRadius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.lighter(root.base, 1.18)
            }
            GradientStop {
                position: 0.55
                color: root.base
            }
            GradientStop {
                position: 1
                color: Qt.darker(root.base, 1.4)
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    // --- Glanz: die obere Haelfte aufhellen, schraeg auslaufend ----------
    // Das ist der eigentliche Glaseindruck. `clip` haelt ihn in der
    // abgerundeten Form; ohne das steht er ueber die Ecken hinaus.
    Item {
        anchors.fill: face
        clip: true

        Rectangle {
            width: parent.width * 1.6
            height: parent.height * 0.62
            x: -parent.width * 0.3
            y: -parent.height * 0.1
            rotation: -7
            transformOrigin: Item.Center
            opacity: 0.5

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
        }
    }

    // --- Kanten: oben hell, unten dunkel ---------------------------------
    Rectangle {
        anchors.fill: face
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    Rectangle {
        anchors.left: face.left
        anchors.right: face.right
        anchors.top: face.top
        anchors.margins: 1
        height: 1
        color: Qt.rgba(1, 1, 1, 0.3)
    }
}
