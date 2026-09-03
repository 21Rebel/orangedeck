// Ein Auswahlfeld. Zugeklappt eine Zeile, aufgeklappt eine Liste darunter.
//
// Selbst gebaut, weil das Projekt **kein Qt Quick Controls** benutzt: die
// geteilten Bausteine haengen an nichts ausser Qt Quick, sonst liefen sie
// weder unter Quickshell noch auf Android. Aus demselben Grund gibt es hier
// kein `Popup` -- die Liste ist ein gewoehnliches Element mit hohem `z`, und
// der Wirt darf sie nicht beschneiden (`clip`).
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    // [{ "k": <schluessel>, "l": <beschriftung> }, ...]
    property var model: []
    property string current: ""
    property bool offen: false
    // Wie viele Zeilen die aufgeklappte Liste hoechstens zeigt
    property int maxZeilen: 9
    // **Der Rahmen, in dem die Liste bleiben muss.** In QML zeichnet ein Kind
    // ungehindert ueber die Grenzen seines Elternteils hinaus -- im
    // Dashboard-Tab stand die Liste dadurch neben der Flaeche, im
    // durchsichtigen Rand des Popout-Fensters. Sie wird deshalb an diesem
    // Element ausgerichtet: seitlich hineingeschoben, und nach oben
    // aufgeklappt, wenn unten kein Platz mehr ist.
    property Item bounds: root.parent

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    property color flaecheColor: "#16161f"
    property real uiFont: 12

    signal picked(string key)

    readonly property real zeilenHoehe: Math.round(root.uiFont * 2.0)
    readonly property real listeHoehe: Math.min(root.maxZeilen, root.model.length)
                                       * root.zeilenHoehe + 6
    readonly property real listeBreite: Math.max(feld.width,
                                                 inhalt.breiteste + root.uiFont * 2)
    // Lage des Feldes im Bezugsrahmen.
    //
    // **Nicht als Bindung.** `mapToItem` liest die Lage einmal aus und meldet
    // sich nie wieder -- eine Bindung darauf rechnet mit dem Stand vom
    // Erzeugen, als die Anker noch nicht aufgeloest waren. Ein Feld unten in
    // der Flaeche hielt sich dadurch fuer eines oben und legte seine Liste an
    // die falsche Stelle. Gemessen wird deshalb beim Aufklappen -- dann, wenn
    // es darauf ankommt, und nur dann.
    property point lage: Qt.point(0, 0)

    function lageMessen() {
        if (root.bounds)
            root.lage = root.mapToItem(root.bounds, 0, 0);
    }

    onOffenChanged: if (root.offen) root.lageMessen()
    onWidthChanged: if (root.offen) root.lageMessen()
    onHeightChanged: if (root.offen) root.lageMessen()
    Component.onCompleted: root.lageMessen()
    // Unten kein Platz, oben schon -> nach oben aufklappen
    readonly property bool nachOben: root.bounds
        && root.lage.y + feld.height + root.listeHoehe + 3 > root.bounds.height
        && root.lage.y - root.listeHoehe - 3 >= 0

    implicitWidth: feld.implicitWidth
    implicitHeight: feld.height
    height: feld.height

    function beschriftung(k) {
        for (var i = 0; i < root.model.length; i++) {
            if (root.model[i].k === k)
                return root.model[i].l;
        }
        return k;
    }

    Rectangle {
        id: feld

        width: root.width
        implicitWidth: text.implicitWidth + pfeil.width + root.uiFont * 2.2
        height: Math.round(root.uiFont * 2.0)
        radius: height / 2
        color: maus.containsMouse || root.offen ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        border.width: 1
        border.color: root.offen ? root.accentColor : root.lineColor

        Text {
            id: text

            anchors.left: parent.left
            anchors.leftMargin: root.uiFont * 0.8
            anchors.verticalCenter: parent.verticalCenter
            text: root.beschriftung(root.current)
            color: root.textColor
            font.pixelSize: root.uiFont
        }

        // Ein gezeichnetes Dreieck statt eines Zeichens -- ein Schriftzeichen
        // haette je nach Schrift eine andere Groesse und Lage.
        Canvas {
            id: pfeil

            anchors.right: parent.right
            anchors.rightMargin: root.uiFont * 0.7
            anchors.verticalCenter: parent.verticalCenter
            width: root.uiFont * 0.7
            height: root.uiFont * 0.45

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.dimColor;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width / 2, height);
                ctx.closePath();
                ctx.fill();
            }
        }

        MouseArea {
            id: maus

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.offen = !root.offen
        }
    }

    // Fangflaeche: ein Klick daneben klappt wieder zu. Sie liegt **unter** der
    // Liste, aber ueber allem anderen.
    MouseArea {
        parent: root.parent
        anchors.fill: parent
        z: 90
        visible: root.offen
        onClicked: root.offen = false
    }

    Rectangle {
        id: liste

        // Rechtsbuendig unter dem Feld -- aber nur, solange das im Rahmen
        // bleibt. Sonst wird sie hineingeschoben.
        x: {
            var wunsch = feld.width - root.listeBreite;
            if (!root.bounds)
                return wunsch;
            var imRahmen = root.lage.x + wunsch;
            var geklemmt = Math.max(0, Math.min(root.bounds.width - root.listeBreite,
                                                imRahmen));
            return geklemmt - root.lage.x;
        }
        y: root.nachOben ? -root.listeHoehe - 3 : feld.height + 3
        width: root.listeBreite
        height: root.listeHoehe
        readonly property real zeilenHoehe: root.zeilenHoehe
        radius: root.uiFont * 0.5
        color: root.flaecheColor
        border.width: 1
        border.color: root.lineColor
        visible: root.offen
        z: 100
        clip: true

        Column {
            id: inhalt

            anchors.fill: parent
            anchors.margins: 3

            // **Gemessen, nicht gerechnet** -- und declarativ: ein verstecktes
            // Textelement je Eintrag. Der Umweg ueber eine Funktion, die einen
            // gemeinsamen Messtext umsetzt, ist ein Seiteneffekt in einer
            // Bindung: er rechnet einmal richtig und danach nicht mehr.
            property real breiteste: {
                var w = 0;
                for (var i = 0; i < masse.count; i++) {
                    var e = masse.itemAt(i);
                    if (e)
                        w = Math.max(w, e.implicitWidth);
                }
                return w;
            }

            Repeater {
                model: root.model

                Rectangle {
                    id: zeile

                    required property var modelData

                    width: inhalt.width
                    height: liste.zeilenHoehe
                    radius: root.uiFont * 0.4
                    color: zeile.modelData.k === root.current
                           ? Qt.rgba(root.accentColor.r, root.accentColor.g,
                                     root.accentColor.b, 0.18)
                           : (zeileMaus.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: root.uiFont * 0.7
                        anchors.verticalCenter: parent.verticalCenter
                        text: zeile.modelData.l
                        color: zeile.modelData.k === root.current ? root.accentColor : root.textColor
                        font.pixelSize: root.uiFont
                    }

                    MouseArea {
                        id: zeileMaus

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.offen = false;
                            root.picked(zeile.modelData.k);
                        }
                    }
                }
            }
        }
    }

    // Unsichtbarer Massstab fuer die Breite der Liste
    Item {
        visible: false

        Repeater {
            id: masse

            model: root.model

            Text {
                required property var modelData

                text: modelData.l
                font.pixelSize: root.uiFont
            }
        }
    }
}
