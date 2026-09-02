// Umschalter und Legende fuer die Kachelfarbe -- die "Mempool-Goggles".
//
// Dieselben Kacheln, zwei Lesarten:
//
//   Gebuehr  teal bis violett nach sat/vB, die Farben des Originals
//   Art      was die Transaktion **tut**, gedeutet aus dem Bitfeld `flags`
//            von mempool.space (siehe txtype.js)
//
// Die Legende zeigt nur, was im Block auch vorkommt, mit der jeweiligen
// Anzahl -- eine Farbe ohne Kachel dazu waere nur Rauschen.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "txtype.js" as TxType

pragma ComponentBehavior: Bound

Column {
    id: root

    property string mode: "fee"           // fee | age | type
    // Welche Lesarten angeboten werden. Der Explorer kennt zwei, der Feed
    // drei -- dort gibt es zusaetzlich das Alter, weil die Halde staendig
    // nachwaechst und ein fertiger Block nicht.
    property var modes: [
        { "k": "fee", "l": "Gebühr" },
        { "k": "type", "l": "Art" }
    ]
    // Zusatzzeile unter der Legende, wenn die Art nicht ueberall gilt
    property string note: ""
    // Anzahl je Art, Index wie in TxType.KINDS
    property var counts: []
    property int total: 0
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13

    signal picked(string mode)

    spacing: uiFont * 0.4

    // ------------------------------------------------------- Umschalter
    Row {
        spacing: root.uiFont * 0.9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Farbe:"
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }

        Repeater {
            model: root.modes

            Item {
                id: knopf

                required property var modelData

                readonly property bool aktiv: root.mode === knopf.modelData.k

                width: beschriftung.width + root.uiFont * 1.2
                height: beschriftung.height + root.uiFont * 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: knopf.aktiv ? Qt.rgba(1, 1, 1, 0.12)
                                       : (maus.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
                                                             : "transparent")
                    border.width: 1
                    border.color: knopf.aktiv ? root.accentColor : Qt.rgba(1, 1, 1, 0.1)
                }

                Text {
                    id: beschriftung

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: knopf.aktiv ? root.textColor : root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }

                MouseArea {
                    id: maus

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(knopf.modelData.k)
                }
            }
        }
    }

    // ---------------------------------------------------------- Legende
    Flow {
        width: parent.width
        spacing: root.uiFont * 1.1
        visible: root.mode === "type"

        Repeater {
            model: {
                var out = [];
                for (var i = 0; i < (root.counts || []).length; i++) {
                    if (root.counts[i] > 0)
                        out.push({ "i": i, "n": root.counts[i] });
                }
                // Haeufigstes zuerst -- so steht vorn, was das Bild praegt
                out.sort(function (a, b) {
                    return b.n - a.n;
                });
                return out;
            }

            Row {
                id: eintrag

                required property var modelData

                readonly property var meta: TxType.info(TxType.kindAt(eintrag.modelData.i))

                spacing: root.uiFont * 0.35

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.uiFont * 0.7
                    height: width
                    radius: 2
                    color: eintrag.meta.color
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: eintrag.meta.label
                    color: root.textColor
                    font.pixelSize: root.uiFont * 0.8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Was vorkommt, aber unter ein halbes Prozent faellt, darf
                    // nicht als "0 %" dastehen -- gerade die seltenen Arten
                    // sind der Grund, ueberhaupt umzuschalten.
                    text: {
                        if (root.total <= 0)
                            return "";
                        var p = 100 * eintrag.modelData.n / root.total;
                        return p < 0.5 ? "<1 %" : Math.round(p) + " %";
                    }
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.8
                }
            }
        }
    }

    // Die Deutung ist eine Deutung -- das gehoert dazugesagt.
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        visible: root.mode === "type"
        text: (root.note.length ? root.note + " " : "")
              + "Bitcoin kennt keine Transaktionsarten. Was hier steht, ist aus der "
              + "Form der Transaktion gedeutet — nützlich, aber nie sicher."
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.75
    }
}
