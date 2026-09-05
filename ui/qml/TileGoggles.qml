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
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Column {
    id: root

    property string mode: "fee"           // fee | age | type
    // Welche Lesarten angeboten werden. Der Explorer kennt zwei, der Feed
    // drei -- dort gibt es zusaetzlich das Alter, weil die Halde staendig
    // nachwaechst und ein fertiger Block nicht.
    property var modes: [
        { "k": "fee", "l": Tr.t("color.fee", lang) },
        { "k": "type", "l": Tr.t("color.type", lang) }
    ]
    // Zusatzzeile unter der Legende, wenn die Art nicht ueberall gilt
    property string note: ""
    // Im Feed sitzt der Umschalter unter der Legende am rechten Rand
    property bool alignRight: false
    // Anzahl je Art, Index wie in TxType.KINDS
    property var counts: []
    property int total: 0
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property real uiFont: 13
    property string lang: "de"
    // Was vor den Knoepfen steht. Der Umschalter wird nicht nur fuer Farben
    // benutzt, sondern auch fuer die Zeitraeume der Kurskurve -- dort waere
    // "Farbe:" schlicht falsch. Ein leerer Wert laesst die Beschriftung weg.
    property string labelKey: "color.label"

    signal picked(string mode)

    // Wie breit die Knopfreihe wirklich ist. Der Feed setzt seine Breite
    // danach, damit der Untergrund dahinter die Knoepfe genau umschliesst --
    // eine von Hand geratene Breite war mal zu schmal (die Knoepfe standen
    // ueber den Rand hinaus) und mal zu breit (der Kasten trug links eine
    // leere Flaeche vor sich her).
    readonly property real schalterBreite: schalterZeile.implicitWidth

    spacing: uiFont * 0.4

    // ------------------------------------------------------- Umschalter
    Row {
        id: schalterZeile

        anchors.right: root.alignRight ? parent.right : undefined
        spacing: root.uiFont * 0.9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Kein `width` von Hand: ein `Row` ueberspringt unsichtbare Kinder
            // ohnehin, und `width: implicitWidth` an einem Text ist eine
            // Bindungsschleife -- Qt meldete sie bei jedem Start.
            visible: root.labelKey !== ""
            text: root.labelKey === "" ? "" : Tr.t(root.labelKey, root.lang)
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
        // **Nicht blosses `mode === "type"`.** Wo keine Anzahlen geliefert
        // werden -- im Feed ist das der Regelfall -- bleibt die Zeile leer,
        // zaehlt in der Spalte aber weiter als sichtbares Kind und traegt
        // ihren Abstand bei. Der Untergrund dahinter wurde dadurch hoeher als
        // das, was er umschliesst.
        visible: root.mode === "type" && (root.counts || []).length > 0

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
                    text: Tr.t(TxType.labelKey(TxType.kindAt(eintrag.modelData.i)), root.lang)
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
                        return p < 0.5 ? Tr.t("pct.lessThanOne", root.lang)
                                       : Math.round(p) + " %";
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
        // Nur dort, wo auch die Farbtafel steht. Im Feed sagt die Legende
        // rechts dasselbe schon -- zweimal waere es nur Rauschen.
        visible: root.mode === "type"
                 && (root.note.length > 0 || (root.counts || []).length > 0)
        text: (root.note.length ? root.note + " " : "") + Tr.t("goggles.note", root.lang)
        color: root.dimColor
        font.pixelSize: root.uiFont * 0.75
    }
}
