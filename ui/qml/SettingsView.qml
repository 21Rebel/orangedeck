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
import "money.js" as Money
import "strings.js" as Tr

pragma ComponentBehavior: Bound

Item {
    id: root

    property var opts: ({})
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property real uiFont: 13
    property string lang: "de"
    // Deckkraft und Startansicht gehoeren dem Fenster. Im Dashboard-Tab
    // stellt die Flaeche der Wirt, dort waeren beide wirkungslos.
    property bool windowed: true

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
        if (!v || !v.length || typeof v.indexOf !== "function")
            return true;
        return v.indexOf(id) >= 0;
    }

    function toggleIn(key, id, alle) {
        var v = root.val(key, []);
        var cur = (!v || !v.length || typeof v.slice !== "function")
            ? alle.slice() : v.slice();
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

    component Wahl: Flow {
        id: wahlRoot

        // `Flow` statt `Row`: dreizehn Sprachen passen in keine Zeile mehr,
        // und abgeschnittene Knoepfe sind schlimmer als zwei Zeilen.
        width: parent ? parent.width : 0

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
            text: Tr.fixed(Math.round(reglerRoot.wert * 100) / 100, 2, root.lang)
                        .replace(/[.,]00$/, "")
                  + reglerRoot.einheit
            color: root.dimColor
            font.pixelSize: root.uiFont * 0.8
        }
    }

    // Kaestchen zum An- und Abwaehlen, fuer Mehrfachauswahl
    component Haken: Flow {
        id: hakenRoot

        width: parent ? parent.width : 0

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
        labels: [Tr.t("set.general", root.lang), Tr.t("tab.feed", root.lang),
                 Tr.t("tab.clock", root.lang), Tr.t("tab.miner", root.lang),
                 Tr.t("tab.explorer", root.lang), Tr.t("tab.wallet", root.lang)]
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
                    label: Tr.t("set.source", root.lang)
                    help: Tr.t("set.sourceHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("dataSource", "daemon")
                        eintraege: [
                            { "k": "daemon", "l": Tr.t("src.daemon", root.lang) },
                            { "k": "direct", "l": Tr.t("src.direct", root.lang) }
                        ]
                        onPicked: function (k) {
                            root.changed("dataSource", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.currency", root.lang)
                    help: Tr.t("set.currencyHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("currency", "eur")
                        eintraege: {
                            var out = [];
                            for (var i = 0; i < Money.CURRENCIES.length; i++) {
                                out.push({ "k": Money.CURRENCIES[i].k,
                                           "l": Money.CURRENCIES[i].z });
                            }
                            return out;
                        }
                        onPicked: function (k) {
                            root.changed("currency", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.language", root.lang)
                    help: Tr.t("set.languageHelp", root.lang)

                    Wahl {
                        gewaehlt: root.lang
                        eintraege: Tr.languages()
                        onPicked: function (k) {
                            root.changed("lang", k);
                        }
                    }
                }

                Zeile {
                    visible: root.windowed
                    label: Tr.t("set.opacity", root.lang)
                    help: Tr.t("set.opacityHelp", root.lang)

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
                    label: Tr.t("set.tileSize", root.lang)
                    help: Tr.t("set.tileSizeHelp", root.lang)

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
                    visible: root.windowed
                    label: Tr.t("set.startView", root.lang)
                    help: Tr.t("set.startViewHelp", root.lang)

                    Wahl {
                        gewaehlt: String(root.val("startView", -1))
                        eintraege: [
                            { "k": "-1", "l": Tr.t("set.lastUsed", root.lang) },
                            { "k": "0", "l": Tr.t("tab.feed", root.lang) },
                            { "k": "1", "l": Tr.t("tab.clock", root.lang) },
                            { "k": "2", "l": Tr.t("tab.miner", root.lang) },
                            { "k": "3", "l": Tr.t("tab.explorer", root.lang) }
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
                    label: Tr.t("set.tileColor", root.lang)
                    help: Tr.t("set.tileColorHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("colorMode", "age")
                        eintraege: [
                            { "k": "age", "l": Tr.t("color.age", root.lang) },
                            { "k": "fee", "l": Tr.t("color.fee", root.lang) },
                            { "k": "type", "l": Tr.t("color.type", root.lang) }
                        ]
                        onPicked: function (k) {
                            root.changed("colorMode", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.tileMetric", root.lang)
                    help: Tr.t("set.tileMetricHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("sizeMode", "value")
                        eintraege: [
                            { "k": "value", "l": Tr.t("feed.sizeValue", root.lang) },
                            { "k": "vbytes", "l": "vBytes" }
                        ]
                        onPicked: function (k) {
                            root.changed("sizeMode", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.header", root.lang)
                    help: Tr.t("set.headerHelp", root.lang)

                    Schalter {
                        an: root.val("showHeader", true)
                        onUmgelegt: root.changed("showHeader", !root.val("showHeader", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.footer", root.lang)
                    help: Tr.t("set.footerHelp", root.lang)

                    Schalter {
                        an: root.val("showFooter", true)
                        onUmgelegt: root.changed("showFooter", !root.val("showFooter", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.blockInfo", root.lang)
                    help: Tr.t("set.blockInfoHelp", root.lang)

                    Schalter {
                        an: root.val("showInfo", true)
                        onUmgelegt: root.changed("showInfo", !root.val("showInfo", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.blockTiles", root.lang)
                    help: Tr.t("set.blockTilesHelp", root.lang)

                    Schalter {
                        an: root.val("showBlock", true)
                        onUmgelegt: root.changed("showBlock", !root.val("showBlock", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.legend", root.lang)
                    help: Tr.t("set.legendHelp", root.lang)

                    Schalter {
                        an: root.val("showLegend", true)
                        onUmgelegt: root.changed("showLegend", !root.val("showLegend", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.ruler", root.lang)
                    help: Tr.t("set.rulerHelp", root.lang)

                    Schalter {
                        an: root.val("showRuler", true)
                        onUmgelegt: root.changed("showRuler", !root.val("showRuler", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.blur", root.lang)
                    help: Tr.t("set.blurHelp", root.lang)

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
                    label: Tr.t("set.metrics", root.lang)
                    help: Tr.t("set.metricsClockHelp", root.lang)

                    Haken {
                        schluessel: "clockFields"
                        alle: ["fee", "price", "moscow", "mempool", "hashrate"]
                        eintraege: [
                            { "id": "fee", "l": Tr.t("fee", root.lang) },
                            { "id": "price", "l": Tr.t("price", root.lang) },
                            { "id": "moscow", "l": Tr.t("clock.moscow", root.lang) },
                            { "id": "mempool", "l": Tr.t("mempool", root.lang) },
                            { "id": "hashrate", "l": Tr.t("hashrate", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.bigValue", root.lang)
                    help: Tr.t("set.bigValueHelp", root.lang)

                    Haken {
                        schluessel: "bigFields"
                        alle: ["height", "price", "moscow", "fee", "hashrate", "mempool", "time"]
                        eintraege: [
                            { "id": "height", "l": Tr.t("blockHeight", root.lang) },
                            { "id": "price", "l": Tr.t("price", root.lang) },
                            { "id": "moscow", "l": Tr.t("clock.moscow", root.lang) },
                            { "id": "fee", "l": Tr.t("fee", root.lang) },
                            { "id": "hashrate", "l": Tr.t("hashrate", root.lang) },
                            { "id": "mempool", "l": Tr.t("mempool", root.lang) },
                            { "id": "time", "l": Tr.t("set.clockTime", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.rotate", root.lang)
                    help: Tr.t("set.rotateHelp", root.lang)

                    Wahl {
                        gewaehlt: String(root.val("bigRotate", 0))
                        eintraege: [
                            { "k": "0", "l": Tr.t("set.off", root.lang) },
                            { "k": "5", "l": Tr.t("unit.sec", root.lang, 5) },
                            { "k": "10", "l": Tr.t("unit.sec", root.lang, 10) },
                            { "k": "30", "l": Tr.t("unit.sec", root.lang, 30) },
                            { "k": "60", "l": Tr.t("unit.sec", root.lang, 60) }
                        ]
                        onPicked: function (k) {
                            root.changed("bigRotate", parseInt(k, 10));
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.diffBars", root.lang)
                    help: Tr.t("set.diffBarsHelp", root.lang)

                    Schalter {
                        an: root.val("clockBars", true)
                        onUmgelegt: root.changed("clockBars", !root.val("clockBars", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.hashChart", root.lang)
                    help: Tr.t("set.hashChartHelp", root.lang)

                    Schalter {
                        an: root.val("clockSpark", true)
                        onUmgelegt: root.changed("clockSpark", !root.val("clockSpark", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.clockTime", root.lang)
                    help: Tr.t("set.clockTimeHelp", root.lang)

                    Schalter {
                        an: root.val("clockTime", false)
                        onUmgelegt: root.changed("clockTime", !root.val("clockTime", false))
                    }
                }
            }

            // ----------------------------------------------------- Miner
            Column {
                width: parent.width
                visible: root.tab === "miner"

                Zeile {
                    label: Tr.t("set.metrics", root.lang)
                    help: Tr.t("set.metricsMinerHelp", root.lang)

                    Haken {
                        schluessel: "minerFields"
                        alle: ["temp", "power", "fan", "error", "shares", "uptime"]
                        eintraege: [
                            { "id": "temp", "l": Tr.t("miner.temp", root.lang) },
                            { "id": "power", "l": Tr.t("miner.power", root.lang) },
                            { "id": "fan", "l": Tr.t("miner.fan", root.lang) },
                            { "id": "error", "l": Tr.t("miner.errorRate", root.lang) },
                            { "id": "shares", "l": Tr.t("miner.shares", root.lang) },
                            { "id": "uptime", "l": Tr.t("miner.uptime", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.minerChart", root.lang)
                    help: Tr.t("set.minerChartHelp", root.lang)

                    Schalter {
                        an: root.val("minerChart", true)
                        onUmgelegt: root.changed("minerChart", !root.val("minerChart", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.minerDomains", root.lang)
                    help: Tr.t("set.minerDomainsHelp", root.lang)

                    Schalter {
                        an: root.val("minerDomains", true)
                        onUmgelegt: root.changed("minerDomains", !root.val("minerDomains", true))
                    }
                }

                Zeile {
                    label: Tr.t("set.minerBoard", root.lang)
                    help: Tr.t("set.minerBoardHelp", root.lang)

                    Schalter {
                        an: root.val("minerBoard", true)
                        onUmgelegt: root.changed("minerBoard", !root.val("minerBoard", true))
                    }
                }
            }

            // -------------------------------------------------- Explorer
            Column {
                width: parent.width
                visible: root.tab === "explorer"

                Zeile {
                    label: Tr.t("set.explorerColor", root.lang)
                    help: Tr.t("set.explorerColorHelp", root.lang)

                    Wahl {
                        gewaehlt: root.val("tileColorMode", "fee")
                        eintraege: [
                            { "k": "fee", "l": Tr.t("color.fee", root.lang) },
                            { "k": "type", "l": Tr.t("color.type", root.lang) }
                        ]
                        onPicked: function (k) {
                            root.changed("tileColorMode", k);
                        }
                    }
                }

                Zeile {
                    label: Tr.t("set.homeParts", root.lang)
                    help: Tr.t("set.homePartsHelp", root.lang)

                    Haken {
                        schluessel: "explorerParts"
                        alle: ["stats", "chain", "next", "panels", "recent"]
                        eintraege: [
                            { "id": "stats", "l": Tr.t("set.metrics", root.lang) },
                            { "id": "chain", "l": Tr.t("chain.label", root.lang) },
                            { "id": "next", "l": Tr.t("nextBlock", root.lang) },
                            { "id": "panels", "l": Tr.t("set.whichPanels", root.lang) },
                            { "id": "recent", "l": Tr.t("addr.lastTxs", root.lang) }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.whichPanels", root.lang)
                    help: Tr.t("set.whichPanelsHelp", root.lang)

                    Haken {
                        schluessel: "explorerPanels"
                        alle: ["fees", "difficulty", "mempool", "rbf"]
                        eintraege: [
                            { "id": "fees", "l": Tr.t("fees", root.lang) },
                            { "id": "difficulty", "l": Tr.t("difficulty", root.lang) },
                            { "id": "mempool", "l": Tr.t("mempool", root.lang) },
                            { "id": "rbf", "l": "RBF" }
                        ]
                    }
                }

                Zeile {
                    label: Tr.t("set.trackProjected", root.lang)
                    help: Tr.t("set.trackProjectedHelp", root.lang)

                    Schalter {
                        an: root.val("explorerLive", true)
                        onUmgelegt: root.changed("explorerLive", !root.val("explorerLive", true))
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
                    text: Tr.t("set.walletTitle", root.lang)
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
                            text: Tr.t("set.walletWarnTitle", root.lang)
                            color: root.accentColor
                            font.pixelSize: root.uiFont
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: Tr.t("set.walletWarn", root.lang)
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
                            text: Tr.t(root.val("walletEnabled", false)
                                       ? "set.walletDisable" : "set.walletEnable", root.lang)
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
                    text: Tr.t("set.walletCli", root.lang)
                          + "\n    orangedeck --watch-add <xpub|ypub|zpub> \"Name\""
                    color: root.dimColor
                    font.pixelSize: root.uiFont * 0.85
                    font.family: "monospace"
                }
            }
        }
    }
}
