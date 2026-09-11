// Das Netz: der zweite Teil des Miner-Reiters. Wie viel gerechnet wird, wie
// schwer es ist, wer die Bloecke findet -- damit der Reiter auch ohne eigenen
// Miner etwas zeigt, und damit man mit einem den Massstab vor Augen hat.
//
// Die Kennzahlen stehen schon im Zustand (`difficulty`, `hashrate`, `tip`)
// und kosten nichts. Verlauf und Pools holt diese Ansicht selbst ueber
// `feed.network()`, und zwar nur, solange sie zu sehen ist -- aus demselben
// Grund wie der Kursverlauf.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property string lang: "de"
    // Sieht niemand hin, wird auch nichts geholt
    property bool live: true
    // 30d | 90d | 1y | 3y | max -- der Wirt haelt ihn
    property string span: "1y"
    property bool finger: false
    // Was gezeigt wird: "stats", "chart", "pools". Leer heisst alles.
    property var parts: []
    function zeigt(p) {
        var v = root.parts;
        if (!v || !v.length || typeof v.indexOf !== "function")
            return true;
        return v.indexOf(p) >= 0;
    }
    // Platz oben fuer den Umschalter "Geraet | Netz", den `MinerView` darueber
    // legt. Er rollt nicht mit.
    property real topInset: 0
    // Unter allem ein Hinweis, wie der eigene Miner dazukommt -- nur, wenn
    // noch keiner eingetragen ist.
    property string footer: ""
    property string footerCommand: ""

    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color diffColor: "#e8e4f0"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))

    signal spanRequested(string s)

    readonly property var diff: feed ? feed.difficulty : ({})
    readonly property var hr: feed ? feed.hashrate : ({})
    readonly property var tip: feed ? feed.tip : ({})

    // -------------------------------------------------------- Daten holen
    property var reihe: []
    property var stufen: []
    property var pools: null
    property bool laden: false
    property string fehler: ""
    // Nur die letzte Anfrage zaehlt (siehe PriceChart: beim Start fragt die
    // Vorgabe, gleich danach der gespeicherte Zeitraum).
    property int __anfrage: 0

    // Die Kennzahlen stehen im Zustand; geholt wird nur, wenn Graph oder
    // Pools zu sehen sind.
    readonly property bool braucht: root.zeigt("chart") || root.zeigt("pools")

    function holen() {
        if (!root.feed || !root.live || !root.braucht)
            return;
        root.laden = true;
        var nr = ++root.__anfrage;
        root.feed.network(root.span, function (d, err) {
            if (nr !== root.__anfrage)
                return;
            root.laden = false;
            if (err || !d) {
                root.fehler = err || "nicht erreichbar";
                return;
            }
            root.fehler = d.error || "";
            root.reihe = d.hashrate || [];
            root.stufen = d.difficulty || [];
            if (d.pools)
                root.pools = d.pools;
        });
    }

    onSpanChanged: root.holen()
    onBrauchtChanged: root.holen()
    onLiveChanged: if (root.live) root.holen()
    onFeedChanged: root.holen()
    Component.onCompleted: root.holen()

    // Die Reihe hat einen Punkt am Tag, die Pools aendern sich mit jedem
    // Block ein wenig. Eine halbe Stunde reicht; der Dienst puffert ohnehin.
    Timer {
        interval: 1800000
        repeat: true
        running: root.live
        onTriggered: root.holen()
    }

    // Fuer "vor 4 Min" -- sonst bliebe die Angabe stehen
    property real jetzt: Date.now() / 1000

    Timer {
        interval: 30000
        repeat: true
        running: root.live
        triggeredOnStart: true
        onTriggered: root.jetzt = Date.now() / 1000
    }

    // ------------------------------------------------------------- Texte
    function dauer(sek) {
        if (!(sek > 0))
            return "–";
        var d = Math.floor(sek / 86400), h = Math.floor((sek % 86400) / 3600),
            m = Math.floor((sek % 3600) / 60);
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
    }

    // Blockzeit als Minuten und Sekunden: 585365 ms wird "9:45 Min"
    function minSek(ms) {
        if (!(ms > 0))
            return "–";
        var s = Math.round(ms / 1000);
        var sek = s % 60;
        return Tr.t("duration.min", root.lang,
                    Math.floor(s / 60) + ":" + (sek < 10 ? "0" : "") + sek);
    }

    readonly property var kennzahlen: {
        var d = root.diff, h = root.hr, t = root.tip;
        var aenderung = (d.change !== undefined && d.change !== null)
            ? (d.change >= 0 ? "+" : "−") + Tr.fixed(Math.abs(d.change), 2, root.lang) + " %"
            : "–";
        var seit = t.time ? root.jetzt - t.time : 0;
        return [
            { "k": Tr.t("hashrate", root.lang),
              "v": Tr.big(h.current, root.lang, "H/s"),
              "s": "", "farbe": root.accentColor },
            { "k": Tr.t("difficulty", root.lang),
              "v": Tr.big(h.difficulty, root.lang),
              "s": "", "farbe": root.diffColor },
            { "k": Tr.t("net.nextAdj", root.lang),
              "v": aenderung,
              "s": d.remainingBlocks !== undefined
                   ? Tr.t("clock.remaining", root.lang, Tr.group(d.remainingBlocks, root.lang),
                          root.dauer((d.remainingTime || 0) / 1000))
                   : "",
              "farbe": root.textColor },
            { "k": Tr.t("net.blockTime", root.lang),
              "v": root.minSek(d.timeAvg),
              "s": "", "farbe": root.textColor },
            { "k": Tr.t("net.lastBlock", root.lang),
              "v": !t.time ? "–" : (seit < 60 ? Tr.t("net.justNow", root.lang)
                                              : Tr.t("net.ago", root.lang, root.dauer(seit))),
              "s": t.pool || "", "farbe": root.textColor }
        ];
    }

    // Die Pools: die sechs groessten einzeln, der Rest zusammen. Mehr Farben
    // unterscheidet in einem schmalen Balken niemand.
    readonly property var poolFarben: [root.accentColor, "#f5c16c", "#57b894", "#5dade2",
                                       "#a78bfa", "#e07a8a"]
    readonly property var poolZeilen: {
        var p = root.pools;
        if (!p || !p.list || !p.blockCount)
            return [];
        var out = [], rest = 0;
        for (var i = 0; i < p.list.length; i++) {
            if (i < root.poolFarben.length)
                out.push({ "name": p.list[i].name, "n": p.list[i].blocks,
                           "farbe": root.poolFarben[i] });
            else
                rest += p.list[i].blocks;
        }
        if (rest > 0)
            out.push({ "name": Tr.t("net.others", root.lang), "n": rest,
                       "farbe": Qt.rgba(1, 1, 1, 0.25) });
        return out;
    }

    function prozent(n) {
        var ges = root.pools ? root.pools.blockCount : 0;
        return ges ? Tr.fixed(100 * n / ges, 1, root.lang) + " %" : "";
    }

    // ------------------------------------------------------------- Aufbau
    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin: root.topInset
        clip: true
        contentWidth: width
        contentHeight: body.implicitHeight + root.scaleUnit
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500

        // Schmaler Balken rechts, nur solange es etwas zu rollen gibt
        Rectangle {
            parent: flick
            anchors.right: parent.right
            width: Math.max(2, root.scaleUnit * 0.16)
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: flick.contentHeight > flick.height + 1
            y: flick.contentY + flick.height * (flick.contentY / flick.contentHeight)
            height: flick.height * (flick.height / flick.contentHeight)
            z: 30
        }

        Column {
            id: body

            width: flick.width * 0.9
            x: (flick.width - width) / 2
            // Mittig, solange Platz ist, wie die Geraeteseite -- sonst oben
            // anfangen. Am Telefon ist die Seite hoeher als der Schirm und
            // beginnt damit ohnehin oben.
            y: Math.max(root.scaleUnit * 0.3, (flick.height - implicitHeight) / 2)
            spacing: root.scaleUnit * 0.7

            // ------------------------------------------------ Kennzahlen
            // Zwei Spalten am schmalen Telefon, drei, sobald es passt. Bei 24
            // Einheiten, wie zuerst, standen im Fenster von 1100 Punkten zwei
            // Spalten und drei Zeilen, und der Graph lag unter dem Rand.
            Grid {
                id: raster

                readonly property int spalten: body.width > root.scaleUnit * 16 ? 3 : 2
                readonly property real zelle: (body.width - (spalten - 1) * columnSpacing) / spalten

                visible: root.zeigt("stats")
                width: body.width
                columns: spalten
                columnSpacing: root.scaleUnit * 0.5
                rowSpacing: root.scaleUnit * 0.55

                Repeater {
                    model: root.kennzahlen

                    Column {
                        id: zelle

                        required property var modelData

                        width: raster.zelle
                        spacing: root.scaleUnit * 0.08

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: zelle.modelData.k
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.55
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: zelle.modelData.v
                            color: zelle.modelData.farbe
                            font.pixelSize: root.scaleUnit * 0.85
                            font.weight: Font.DemiBold
                        }

                        // Zwei Zeilen statt abgeschnitten: "noch 1.172 Bloecke ·
                        // 7 Tage 22 Std" passt in einer Drittelspalte nicht.
                        Text {
                            width: parent.width
                            visible: zelle.modelData.s !== ""
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: zelle.modelData.s
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.5
                        }
                    }
                }
            }

            // ----------------------------------------------------- Verlauf
            // Hoehe aus der Breite, nicht aus der Hoehe -- quer wird er nicht
            // gestaucht, hochkant nicht zum Strich (wie der Kurs in der Uhr).
            // Hochkant am Telefon sind das rund 260 Punkte; mit dem Faktor
            // 0,55 waren es 200, und die Kurve eines Jahres lag in einem
            // Streifen.
            NetworkChart {
                visible: root.zeigt("chart")
                width: body.width
                height: Math.max(170, Math.min(body.width * 0.7, 360))
                lang: root.lang
                span: root.span
                reihe: root.reihe
                stufen: root.stufen
                laden: root.laden
                fehler: root.fehler
                baseFont: root.finger ? Math.max(13, root.scaleUnit * 0.5) : root.scaleUnit * 0.5
                minTap: root.finger ? 40 : 0
                textColor: root.textColor
                dimColor: root.dimColor
                accentColor: root.accentColor
                diffColor: root.diffColor
                lineColor: Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.35)
                onSpanRequested: function (sp) {
                    root.spanRequested(sp);
                }
            }

            // ------------------------------------------------------- Pools
            Column {
                width: body.width
                spacing: root.scaleUnit * 0.3
                visible: root.zeigt("pools") && root.poolZeilen.length > 0

                Text {
                    text: Tr.t("net.pools", root.lang,
                               Tr.group(root.pools ? root.pools.blockCount : 0, root.lang))
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                // Der Balken: jedes Stueck so breit wie sein Anteil
                Row {
                    width: parent.width
                    height: Math.max(6, root.scaleUnit * 0.4)

                    Repeater {
                        model: root.poolZeilen

                        Rectangle {
                            id: stueck

                            required property var modelData
                            required property int index

                            width: parent.width * stueck.modelData.n
                                   / Math.max(1, root.pools ? root.pools.blockCount : 1)
                            height: parent.height
                            color: stueck.modelData.farbe
                            // Eine feine Fuge zwischen den Stuecken
                            border.width: 0.5
                            border.color: Qt.rgba(0, 0, 0, 0.35)
                        }
                    }
                }

                // Die Liste darunter, in zwei Spalten, wenn es passt
                Grid {
                    id: liste

                    readonly property int spalten: parent.width > root.scaleUnit * 20 ? 2 : 1

                    width: parent.width
                    columns: spalten
                    columnSpacing: root.scaleUnit * 1.2
                    rowSpacing: root.scaleUnit * 0.15

                    Repeater {
                        model: root.poolZeilen

                        Row {
                            id: poolZeile

                            required property var modelData

                            width: (liste.width - (liste.spalten - 1) * liste.columnSpacing) / liste.spalten
                            spacing: root.scaleUnit * 0.4

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.scaleUnit * 0.45
                                height: width
                                radius: 2
                                color: poolZeile.modelData.farbe
                            }

                            Text {
                                width: poolZeile.width - root.scaleUnit * 0.85 - anteil.width
                                       - root.scaleUnit * 0.4
                                elide: Text.ElideRight
                                text: poolZeile.modelData.name
                                color: root.textColor
                                font.pixelSize: root.scaleUnit * 0.58
                            }

                            Text {
                                id: anteil

                                text: root.prozent(poolZeile.modelData.n)
                                color: root.dimColor
                                font.pixelSize: root.scaleUnit * 0.58
                            }
                        }
                    }
                }
            }

            // Ohne eigenen Miner: wie er dazukommt
            Column {
                width: body.width
                spacing: root.scaleUnit * 0.2
                visible: root.footer !== ""

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.footer
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.5
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.footerCommand !== ""
                    text: root.footerCommand
                    color: root.accentColor
                    font.pixelSize: root.scaleUnit * 0.5
                    font.family: Fonts.mono()
                }
            }
        }
    }
}
