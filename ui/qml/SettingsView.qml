// Einstellungen, nach denselben Reitern geordnet wie die Ansichten.
//
// Die Werte gehoeren dem Wirt: die eigenstaendige Anwendung legt sie ueber
// QSettings ab, das Quickshell-Fenster in view.json, der Dashboard-Tab in den
// Plugin-Einstellungen von DMS. Hier steht nur die Oberflaeche -- sie liest
// `opts` und meldet jede Aenderung ueber `changed` zurueck.
//
// Bewusst mit eigenen kleinen Bedienelementen statt QtQuick.Controls: der Rest
// des Programms kommt mit `import QtQuick` aus, und das soll so bleiben --
// dieselben Dateien laufen im Fenster, im DMS-Plugin und spaeter unter Android.
import QtQuick

pragma ComponentBehavior: Bound

Item {
    id: root

    property var opts: ({})
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property real uiFont: 13

    signal changed(string key, var value)

    property string tab: "allgemein"

    function val(key, fallback) {
        var v = root.opts ? root.opts[key] : undefined;
        return v === undefined ? fallback : v;
    }

    // Eine Mehrfachauswahl wird als Liste von Schluesseln gehalten. Leer heisst
    // **alle** -- so bleibt eine spaeter hinzukommende Kennzahl sichtbar,
    // statt stillschweigend zu fehlen.
    function has(key, id, alle) {
        var v = root.val(key, []);
        if (!v || v.length === 0)
            return true;
        return v.indexOf(id) >= 0;
    }

    function toggleIn(key, id, alle) {
        var v = root.val(key, []);
        var cur = (!v || v.length === 0) ? alle.slice() : v.slice();
        var i = cur.indexOf(id);
        if (i >= 0)
            cur.splice(i, 1);
        else
            cur.push(id);
        root.changed(key, cur);
    }

    // ---------------------------------------------------- Bedienelemente
    component Zeile: Item {
        id: zeileRoot

        property string label: ""
        property string help: ""
        default property alias inhalt: halter.data

        width: parent ? parent.width : 0
        height: Math.max(halter.childrenRect.height, beschriftung.height) + root.uiFont * 1.1

        Column {
            id: beschriftung

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.42
            spacing: 2

            Text {
                text: zeileRoot.label
                color: root.textColor
                font.pixelSize: root.uiFont * 0.95
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: zeileRoot.help
                color: root.dimColor
                font.pixelSize: root.uiFont * 0.78
            }
        }

        Item {
            id: halter

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.54
            height: childrenRect.height
        }
    }

    component Schalter: Rectangle {
        id: schalterRoot

        property bool an: false

        signal umgelegt

        width: root.uiFont * 2.6
        height: root.uiFont * 1.4
        radius: height / 2
        color: an ? root.goodColor : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: schalterRoot.an ? schalterRoot.width - width - 2 : 2
            color: "#ffffff"

            Behavior on x {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: schalterRoot.umgelegt()
        }
    }

    component Wahl: Row {
        id: wahlRoot

        property var eintraege: []      // [{ k, l }]
        property string gewaehlt: ""

        signal picked(string k)

        spacing: root.uiFont * 0.4

        Repeater {
            model: wahlRoot.eintraege

            Rectangle {
                id: knopf

                required property var modelData

                readonly property bool aktiv: wahlRoot.gewaehlt === knopf.modelData.k

                width: knopfText.width + root.uiFont * 1.1
                height: knopfText.height + root.uiFont * 0.55
                radius: height / 2
                color: knopf.aktiv ? Qt.rgba(1, 1, 1, 0.12)
                                   : (maus.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.width: 1
                border.color: knopf.aktiv ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)

                Text {
                    id: knopfText

                    anchors.centerIn: parent
                    text: knopf.modelData.l
                    color: knopf.aktiv ? root.textColor : root.dimColor
                    font.pixelSize: root.uiFont * 0.82
                }

                MouseArea {
                    id: maus

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wahlRoot.picked(knopf.modelData.k)
                }
            }
        }
    }

    component Regler: Item {
        id: reglerRoot

        property real wert: 0
        property real von: 0
        property real bis: 1
        property real schritt: 0.05
        property string einheit: ""

        signal gezogen(real w)

        width: root.uiFont * 16
        height: root.uiFont * 1.6

        Rectangle {
            id: bahn

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.uiFont * 4
            height: Math.max(3, root.uiFont * 0.22)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: bahn.width * Math.max(0, Math.min(1,
                    (reglerRoot.wert - reglerRoot.von) / (reglerRoot.bis - reglerRoot.von)))
                height: parent.height
                radius: height / 2
                color: root.accentColor
            }

            Rectangle {
                width: root.uiFont
                height: width
                radius: width / 2
                y: (parent.height - height) / 2
                x: bahn.width * Math.max(0, Math.min(1,
                    (reglerRoot.wert - reglerRoot.von) / (reglerRoot.bis - reglerRoot.von)))
                   - width / 2
                color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -root.uiFont
                cursorShape: Qt.PointingHandCursor

                function setzen(mx) {
                    var f = Math.max(0, Math.min(1, mx / bahn.width));
                    var w = reglerRoot.von + f * (reglerRoot.bis - reglerRoot.von);
                    var st = reglerRoot.schritt;
                    reglerRoot.gezogen(Math.round(w / st) * st);
                }

                onPressed: mouse => setzen(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setzen(mouse.x);
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (Math.round(reglerRoot.wert * 100) / 100).toString().replace(".", ",")
                  + reglerRoot.einheit
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }
    }

    // Kaestchen zum An- und Abwaehlen, fuer Mehrfachauswahl
    component Haken: Row {
        id: hakenRoot

        property var alle: []
        property string schluessel: ""
        property var eintraege: []     // [{ id, l }]

        spacing: root.uiFont * 0.7

        Repeater {
            model: hakenRoot.eintraege

            // Ein `Item` um die Zeile herum: in einem `Row` darf ein Kind
            // kein `anchors.fill` haben, die Beruehrungsflaeche braucht aber
            // genau das.
            Item {
                id: hak

                required property var modelData

                readonly property bool an: root.has(hakenRoot.schluessel, hak.modelData.id,
                                                    hakenRoot.alle)

                width: hakZeile.width
                height: Math.max(hakZeile.height, root.uiFont * 1.6)

                Row {
                    id: hakZeile

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.uiFont * 0.3

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.uiFont
                        height: width
                        radius: 3
                        color: hak.an ? root.goodColor : "transparent"
                        border.width: 1
                        border.color: hak.an ? root.goodColor : Qt.rgba(1, 1, 1, 0.25)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hak.modelData.l
                        color: hak.an ? root.textColor : root.dimColor
                        font.pixelSize: root.uiFont * 0.82
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleIn(hakenRoot.schluessel, hak.modelData.id,
                                             hakenRoot.alle)
                }
            }
        }
    }

    // ------------------------------------------------------------ Aufbau
    ViewTabs {
        id: reiter

        anchors.left: parent.left
        anchors.top: parent.top
        labels: ["Allgemein", "Feed", "BlockClock", "Miner", "Explorer", "Wallet"]
        current: ["allgemein", "feed", "clock", "miner", "explorer", "wallet"].indexOf(root.tab)
        fontSize: root.uiFont
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        onPicked: function (i) {
            root.tab = ["allgemein", "feed", "clock", "miner", "explorer", "wallet"][i];
        }
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: reiter.bottom
        anchors.topMargin: root.uiFont
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: seite.implicitHeight + root.uiFont * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: seite

            width: parent.width

            // ------------------------------------------------- Allgemein
            Column {
                width: parent.width
                visible: root.tab === "allgemein"

                Zeile {
                    label: "Deckkraft des Fensters"
                    help: "Wie durchsichtig der Hintergrund ist. Ob dahinter weichgezeichnet wird, entscheidet der Compositor."

                    Regler {
                        von: 0.15
                        bis: 1
                        schritt: 0.05
                        wert: root.val("bgOpacity", 0.82)
                        onGezogen: function (w) {
                            root.changed("bgOpacity", w);
                        }
                    }
                }

                Zeile {
                    label: "Kachelgröße"
                    help: "Größer heißt weniger Kacheln nebeneinander, aber besser zu treffen."

                    Regler {
                        von: 0.6
                        bis: 2
                        schritt: 0.1
                        wert: root.val("density", 1)
                        onGezogen: function (w) {
                            root.changed("density", w);
                        }
                    }
                }

                Zeile {
                    label: "Startansicht"
                    help: "Womit das Fenster aufgeht — für ein Tablet an der Wand meist die BlockClock."

                    Wahl {
                        gewaehlt: String(root.val("startView", 0))
                        eintraege: [
                            { "k": "0", "l": "Feed" },
                            { "k": "1", "l": "BlockClock" },
                            { "k": "2", "l": "Miner" },
                            { "k": "3", "l": "Explorer" }
                        ]
                        onPicked: function (k) {
                            root.changed("startView", parseInt(k, 10));
                        }
                    }
                }
            }

            // ------------------------------------------------------ Feed
            Column {
                width: parent.width
                visible: root.tab === "feed"

                Zeile {
                    label: "Farbe der Kacheln"
                    help: "Alter: orange bis blau in einer Minute. Gebühr: nach sat/vB. Art: die gedeutete Transaktionsart — die gilt nur für den Block."

                    Wahl {
                        gewaehlt: root.val("colorMode", "age")
                        eintraege: [
                            { "k": "age", "l": "Alter" },
                            { "k": "fee", "l": "Gebühr" },
                            { "k": "type", "l": "Art" }
                        ]
                        onPicked: function (k) {
                            root.changed("colorMode", k);
                        }
                    }
                }

                Zeile {
                    label: "Größe der Kacheln"
                    help: "Wonach sich die Kantenlänge richtet."

                    Wahl {
                        gewaehlt: root.val("sizeMode", "value")
                        eintraege: [
                            { "k": "value", "l": "Ausgabewert" },
                            { "k": "vbytes", "l": "vBytes" }
                        ]
                        onPicked: function (k) {
                            root.changed("sizeMode", k);
                        }
                    }
                }

                Zeile {
                    label: "Blockangaben"
                    help: "Das Feld links mit Höhe, Wert und Pool."

                    Schalter {
                        an: root.val("showInfo", true)
                        onUmgelegt: root.changed("showInfo", !root.val("showInfo", true))
                    }
                }

                Zeile {
                    label: "Legende"
                    help: "Größen- und Farbtafel rechts, dazu der Umschalter unten."

                    Schalter {
                        an: root.val("showLegend", true)
                        onUmgelegt: root.changed("showLegend", !root.val("showLegend", true))
                    }
                }

                Zeile {
                    label: "Trennlinie über der Halde"
                    help: "Die gestrichelte Linie markiert die Oberkante des Mempools."

                    Schalter {
                        an: root.val("showRuler", true)
                        onUmgelegt: root.changed("showRuler", !root.val("showRuler", true))
                    }
                }

                Zeile {
                    label: "Weichzeichnung hinter der Schrift"
                    help: "Kostet etwas Rechenzeit, macht die Angaben über hellen Kacheln aber lesbar."

                    Schalter {
                        an: root.val("frosted", true)
                        onUmgelegt: root.changed("frosted", !root.val("frosted", true))
                    }
                }
            }

            // ------------------------------------------------ BlockClock
            Column {
                width: parent.width
                visible: root.tab === "clock"

                Zeile {
                    label: "Kennzahlen"
                    help: "Was unter der Blockhöhe steht. Nichts ausgewählt heißt: alles."

                    Haken {
                        schluessel: "clockFields"
                        alle: ["fee", "price", "moscow", "mempool", "hashrate"]
                        eintraege: [
                            { "id": "fee", "l": "Gebühr" },
                            { "id": "price", "l": "Kurs" },
                            { "id": "moscow", "l": "Moscow Time" },
                            { "id": "mempool", "l": "Mempool" },
                            { "id": "hashrate", "l": "Hashrate" }
                        ]
                    }
                }

                Zeile {
                    label: "Währung"
                    help: "Der Daemon holt Euro und Dollar ohnehin beide."

                    Wahl {
                        gewaehlt: root.val("currency", "eur")
                        eintraege: [
                            { "k": "eur", "l": "Euro" },
                            { "k": "usd", "l": "Dollar" }
                        ]
                        onPicked: function (k) {
                            root.changed("currency", k);
                        }
                    }
                }

                Zeile {
                    label: "Schwierigkeit und Halving"
                    help: "Die beiden Balken am unteren Rand."

                    Schalter {
                        an: root.val("clockBars", true)
                        onUmgelegt: root.changed("clockBars", !root.val("clockBars", true))
                    }
                }
            }

            // ----------------------------------------------------- Miner
            Column {
                width: parent.width
                visible: root.tab === "miner"

                Zeile {
                    label: "Kennzahlen"
                    help: "Ab sechs Stück verteilen sie sich auf Zeilen zu je drei."

                    Haken {
                        schluessel: "minerFields"
                        alle: ["temp", "power", "fan", "error", "shares", "uptime"]
                        eintraege: [
                            { "id": "temp", "l": "Temperatur" },
                            { "id": "power", "l": "Leistung" },
                            { "id": "fan", "l": "Lüfter" },
                            { "id": "error", "l": "Fehlerquote" },
                            { "id": "shares", "l": "Freigaben" },
                            { "id": "uptime", "l": "Laufzeit" }
                        ]
                    }
                }
            }

            // -------------------------------------------------- Explorer
            Column {
                width: parent.width
                visible: root.tab === "explorer"

                Zeile {
                    label: "Farbe der Kachelgrafiken"
                    help: "Gilt für Blöcke und den geplanten Block im Explorer."

                    Wahl {
                        gewaehlt: root.val("tileColorMode", "fee")
                        eintraege: [
                            { "k": "fee", "l": "Gebühr" },
                            { "k": "type", "l": "Art" }
                        ]
                        onPicked: function (k) {
                            root.changed("tileColorMode", k);
                        }
                    }
                }
            }

            // ---------------------------------------------------- Wallet
            Column {
                width: parent.width
                spacing: root.uiFont * 0.7
                visible: root.tab === "wallet"

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Wallet-Ansicht"
                    color: root.textColor
                    font.pixelSize: root.uiFont * 1.15
                }

                // Der Reiter erscheint erst, wenn das hier gelesen und
                // bestaetigt wurde. Nicht wegen der Guthaben -- die sind
                // watch-only vollstaendig geschuetzt --, sondern wegen der
                // Verkettung: das ist der einzige Teil des Programms, bei dem
                // der Benutzer etwas ueber sich preisgibt.
                Rectangle {
                    width: parent.width
                    height: warnung.height + root.uiFont * 1.6
                    radius: root.uiFont * 0.4
                    color: Qt.rgba(0.85, 0.55, 0.1, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(0.85, 0.55, 0.1, 0.45)

                    Column {
                        id: warnung

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.uiFont * 0.8
                        spacing: root.uiFont * 0.5

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Bevor Sie das einschalten"
                            color: root.accentColor
                            font.pixelSize: root.uiFont
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Ihr Guthaben ist nicht in Gefahr: hier liegt nur ein öffentlicher "
                                  + "Schlüssel, das Programm kann nicht signieren und nimmt keinen "
                                  + "privaten Schlüssel entgegen. Der Schlüssel verlässt das Gerät nie.\n\n"
                                  + "Was Sie aufgeben, ist Privatsphäre. Die Adressen werden hier "
                                  + "abgeleitet und einzeln bei mempool.space abgefragt — wer viele "
                                  + "Adressen kurz nacheinander von derselben Stelle abfragt, zeigt "
                                  + "dem Betreiber, dass sie zusammengehören. Er sieht damit Ihre "
                                  + "Wallet, ohne sie je bekommen zu haben.\n\n"
                                  + "Vollständig lösen lässt sich das nur mit einem eigenen Knoten "
                                  + "(electrs). Auf einem fremden oder geteilten Rechner sollten Sie "
                                  + "diese Ansicht ausgelassen lassen."
                            color: root.textColor
                            font.pixelSize: root.uiFont * 0.85
                        }
                    }
                }

                Row {
                    spacing: root.uiFont * 0.6

                    Rectangle {
                        width: zusage.width + root.uiFont * 1.6
                        height: zusage.height + root.uiFont * 0.8
                        radius: height / 2
                        color: root.val("walletEnabled", false)
                            ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.rgba(0.34, 0.72, 0.58, 0.9)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)

                        Text {
                            id: zusage

                            anchors.centerIn: parent
                            text: root.val("walletEnabled", false)
                                ? "Wallet-Ansicht wieder ausblenden"
                                : "Verstanden — Wallet-Ansicht einschalten"
                            color: root.val("walletEnabled", false) ? root.dimColor : "#0b0b12"
                            font.pixelSize: root.uiFont * 0.9
                            font.bold: !root.val("walletEnabled", false)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changed("walletEnabled",
                                                    !root.val("walletEnabled", false))
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: root.val("walletEnabled", false)
                    text: "Eingetragen wird auf der Kommandozeile — der Dienst im Hintergrund "
                          + "nimmt nichts entgegen:\n"
                          + "    btcfeed --watch-add <xpub|ypub|zpub> \"Name\""
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                    font.family: "monospace"
                }
            }
        }
    }
}
