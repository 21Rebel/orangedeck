// Eigene Miner. Zeigt, was die Geraete melden, und stellt die erreichte
// Schwierigkeit der des Netzes gegenueber -- das ist die Zahl, um die es beim
// Solomining eigentlich geht.
//
// Bewusst **nicht** auf ein Geraet festgelegt: der Daemon spricht AxeOS
// (Bitaxe, NerdAxe und die uebrigen ESP-Miner-Abkoemmlinge) und die
// cgminer-Schnittstelle (Antminer, Avalon, Whatsminer und Nachbauten) und
// liefert beides normalisiert, Hashrate in H/s. Mehrere Geraete zugleich sind
// vorgesehen.
//
// Nur `import QtQuick` -- laeuft damit auch unter Android.
import QtQuick
import "strings.js" as Tr
import "fonts.js" as Fonts

pragma ComponentBehavior: Bound

Item {
    id: root

    property var feed: null
    property color textColor: "#f2eef8"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color goodColor: "#57b894"
    property color badColor: "#d9534f"
    property real scaleUnit: Math.max(10, Math.min(width / 26, height / 16))

    readonly property var miners: feed ? feed.miners : []
    readonly property var total: feed ? feed.minerTotal : ({})
    readonly property bool configured: feed ? feed.minerConfigured : false
    readonly property bool anyOnline: feed ? feed.minerOnline : false
    readonly property real netDiff: (feed && feed.hashrate.difficulty) || 0
    readonly property real bestShare: (netDiff > 0 && total.bestDiff)
        ? total.bestDiff / netDiff : 0
    // Bei genau einem Geraet ist Platz fuer die Einzelheiten
    readonly property var one: (miners.length === 1 && miners[0].online) ? miners[0] : null
    readonly property var oneHist: (one && feed) ? (feed.minerHistory[one.id] || ({})) : ({})
    // Seit der Inhalt rollbar ist, muss nichts mehr wegen Platzmangel
    // wegbleiben. Die Schwellen halten nur noch das ganz kleine
    // Desktop-Widget frei, wo Kurve und Liste sinnlos waeren.
    // Hat der Wirt schon eine Knopfleiste (im Dashboard die von DMS), stellt
    // er die Knoepfe selbst und schaltet unsere ab. Sie sitzen dann in der
    // obersten Zeile, wo nichts sie ueberdecken kann.
    property bool showActions: true
    // Fuer den Wirt: Legende auf- und zuklappen
    function toggleInfo() {
        info.open = !info.open;
    }
    // Weboberflaeche des Geraets oeffnen. Gilt fuer jeden Miner, der eine hat.
    readonly property string webUrl: (one && one.type === "axeos") ? one.id : ""
    function openWeb() {
        if (webUrl)
            Qt.openUrlExternally(webUrl);
    }
    readonly property bool roomForChart: height > 200

    // Welche Kennzahlen ueberhaupt gezeigt werden. Leere Liste heisst alle --
    // die Auswahl kommt aus den Einstellungen, hier steht nur der Filter.
    property var metricKeys: []
    property bool showChart: true
    property bool showDomains: true
    property bool showBoard: true
    property string lang: "de"

    readonly property var metrics: {
        var m = root.one;
        if (!m)
            return [];
        var alle = [
            { "id": "temp", "k": Tr.t("miner.temp", root.lang), "v": (m.temp !== undefined && m.temp !== null)
                ? Math.round(m.temp) + " °C" : "–" },
            { "id": "power", "k": Tr.t("miner.power", root.lang), "v": m.power
                ? Tr.fixed(m.power, 1, root.lang) + " W" : "–" },
            { "id": "fan", "k": Tr.t("miner.fan", root.lang), "v": m.fanRpm ? Tr.t("miner.rpm", root.lang, m.fanRpm) : "–" },
            { "id": "error", "k": Tr.t("miner.errorRate", root.lang), "v": (m.errorPct !== undefined && m.errorPct !== null)
                ? Tr.fixed(m.errorPct, 1, root.lang) + " %" : "–" },
            { "id": "shares", "k": Tr.t("miner.shares", root.lang), "v": m.shares !== undefined
                ? (m.rejected ? Tr.t("miner.rejected", root.lang, m.shares, m.rejected)
                              : String(m.shares)) : "–" },
            { "id": "uptime", "k": Tr.t("miner.uptime", root.lang), "v": root.span(m.uptime) }
        ];
        var mk = root.metricKeys;
        if (!mk || !mk.length || typeof mk.indexOf !== "function")
            return alle;
        return alle.filter(function (x) {
            return mk.indexOf(x.id) >= 0;
        });
    }

    // Ab sechs Kennzahlen auf Zeilen zu je drei verteilen, darunter eine Zeile.
    readonly property var metricRows: {
        var m = root.metrics;
        if (m.length < 6)
            return m.length ? [m] : [];
        var out = [];
        for (var i = 0; i < m.length; i += 3)
            out.push(m.slice(i, i + 3));
        return out;
    }
    readonly property bool roomForBoard: height > 240

    function big(n, unit) {
        if (!n)
            return "–";
        var u = ["", "k", "M", "G", "T", "P", "E"], i = 0;
        while (n >= 1000 && i < u.length - 1) {
            n /= 1000;
            i++;
        }
        return Tr.fixed(n, n >= 100 ? 0 : 2, root.lang)
             + " " + u[i] + (unit || "");
    }

    function span(sec) {
        if (!sec)
            return "–";
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600),
            m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return Tr.t("duration.dayHour", root.lang, d, h);
        if (h > 0)
            return Tr.t("duration.hourMin", root.lang, h, m);
        return Tr.t("duration.min", root.lang, m);
    }

    // Zu den Einstellungen geht es in der Weboberflaeche des Geraets -- die
    // bleiben dort, hier wird nur angezeigt. Nur ein Zeichen, keine
    // Beschriftung: so passt der Knopf fuer jeden Miner.
    // Alle Erklaerungen an einem Ort, statt sie in die Flaeche zu streuen
    InfoPopup {
        id: info

        anchors.fill: parent
        buttonMargin: 0
        showButton: root.showActions
        fontSize: root.scaleUnit * 0.72
        textColor: root.textColor
        dimColor: root.dimColor
        lang: root.lang
        title: Tr.t("miner.whatIsThis", root.lang)
        entries: [
            {
                "color": root.accentColor,
                "thin": true,
                "k": Tr.t("miner.hashNow", root.lang),
                "v": Tr.t("miner.hashNowHelp", root.lang)
            },
            {
                "color": root.accentColor,
                "k": Tr.t("miner.hashAvg", root.lang),
                "v": Tr.t("miner.hashAvgHelp", root.lang)
            },
            {
                "color": root.textColor,
                "k": Tr.t("miner.temp", root.lang),
                "v": Tr.t("miner.tempHelp", root.lang)
            },
            {
                "k": Tr.t("miner.oneToN", root.lang),
                "v": Tr.t("miner.oneToNHelp", root.lang)
            },
            {
                "k": Tr.t("miner.domains", root.lang),
                "v": Tr.t("miner.domainsHelp", root.lang)
            },
            {
                "k": Tr.t("miner.errorRate", root.lang),
                "v": Tr.t("miner.errorHelp", root.lang)
            }
        ]
        z: 40
    }

    Rectangle {
        id: openBtn

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: info.buttonWidth + root.scaleUnit * 0.4
        visible: root.showActions && root.webUrl !== ""
        width: info.buttonWidth
        height: width
        radius: height / 2
        color: openArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        z: 20

        Text {
            anchors.centerIn: parent
            text: "↗"
            color: root.textColor
            font.pixelSize: root.scaleUnit * 0.8
        }

        MouseArea {
            id: openArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWeb()
        }
    }

    // ---------------------------------------------------- kein Geraet bekannt
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.86
        spacing: root.scaleUnit * 0.45
        visible: !root.configured

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("miner.none", root.lang)
            color: root.textColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("miner.discover", root.lang)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "orangedeck --discover-miners --write\nsystemctl --user restart orangedeck"
            horizontalAlignment: Text.AlignHCenter
            color: root.accentColor
            font.pixelSize: root.scaleUnit * 0.62
            font.family: Fonts.mono()
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("miner.detects", root.lang)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.55
        }
    }

    // ------------------------------------------- eingetragen, aber alle aus
    Column {
        anchors.centerIn: parent
        spacing: root.scaleUnit * 0.35
        visible: root.configured && !root.anyOnline

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t(root.miners.length === 1 ? "miner.notReachable"
                                               : "miner.unreachable", root.lang)
            color: root.badColor
            font.pixelSize: root.scaleUnit * 1.1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Tr.t("miner.offNote", root.lang)
            color: root.dimColor
            font.pixelSize: root.scaleUnit * 0.62
        }
    }

    // ------------------------------------------------------------- im Betrieb
    // Der Inhalt kann hoeher werden als die Flaeche -- im Dashboard-Tab
    // (410 px) reicht es nicht fuer Kurve, Rechenwerke und Bestenliste
    // zugleich. Deshalb rollbar: passt alles, bleibt es mittig stehen; passt
    // es nicht, laesst es sich schieben.
    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        visible: root.anyOnline
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
                // Mittig, solange Platz ist -- sonst oben anfangen
                y: Math.max(0, (flick.height - implicitHeight) / 2)
                spacing: root.scaleUnit * 0.45

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.total.online > 1
                    ? Tr.t("miner.devices", root.lang, root.total.online)
                    : (root.miners[0] ? root.miners[0].name : Tr.t("miner.title", root.lang))
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.72
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.big(root.total.hashRate, "H/s")
                color: root.accentColor
                font.pixelSize: root.scaleUnit * 2.6
                font.bold: true
            }

            // Die Momentanrate schwankt um rund zehn Prozent -- oben steht deshalb
            // der geglaettete Zehnminutenwert, hier der Vergleich mit dem, was das
            // Geraet bei seiner Taktung erwarten laesst.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.expected
                text: root.one && root.one.expected
                    ? Tr.t("miner.smoothed", root.lang, root.big(root.one.expected, "H/s"))
                    : ""
                color: root.dimColor
                font.pixelSize: root.scaleUnit * 0.55
            }

            // Der Grund, warum man das ueberhaupt macht
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.one && root.one.blockFound > 0
                width: blockText.width + root.scaleUnit
                height: blockText.height + root.scaleUnit * 0.4
                radius: height / 2
                color: root.goodColor

                Text {
                    id: blockText

                    anchors.centerIn: parent
                    text: root.one && root.one.blockFound > 0
                        ? (root.one.blockFound === 1
                            ? Tr.t("miner.oneBlockFound", root.lang)
                            : Tr.t("miner.blocksFound", root.lang, root.one.blockFound))
                        : ""
                    color: "#0b0b12"
                    font.pixelSize: root.scaleUnit * 0.62
                    font.bold: true
                }
            }

            // Die eigentliche Zahl beim Solomining
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("miner.bestShare", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.total.bestDiff
                        ? root.big(root.total.bestDiff) + " von " + root.big(root.netDiff)
                        : "–"
                    color: root.textColor
                    font.pixelSize: root.scaleUnit * 0.95
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.bestShare > 0
                    // Winzige Anteile -- "1 zu N" liest sich besser als eine
                    // Prozentzahl mit acht Nullen.
                    text: root.bestShare >= 1
                        ? Tr.t("miner.enoughForBlock", root.lang)
                        : Tr.t("miner.oneInN", root.lang, root.big(1 / root.bestShare))
                    color: root.bestShare >= 1 ? root.goodColor : root.dimColor
                    font.pixelSize: root.scaleUnit * 0.62
                }
            }

            Item {
                width: 1
                height: root.scaleUnit * 0.3
            }

            // --------------------------------------- Einzelheiten, ein Geraet
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2
                visible: root.one !== null

                // Die Kennzahlen. Ab sechs Stueck werden sie auf Zeilen zu je
                // drei verteilt -- in einer Reihe liefen sie im Dashboard ueber
                // den Rand hinaus und die aeusseren beiden wurden abgeschnitten.
                // Bis fuenf bleibt es bei einer Zeile.
                Column {
                    width: parent.width
                    spacing: root.scaleUnit * 0.45

                    Repeater {
                        model: root.metricRows

                        Row {
                            id: zeile

                            required property var modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.scaleUnit * 1.1

                            Repeater {
                                model: zeile.modelData

                                Column {
                                    id: cell

                                    required property var modelData

                                    spacing: root.scaleUnit * 0.1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.k
                                        color: root.dimColor
                                        font.pixelSize: root.scaleUnit * 0.55
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cell.modelData.v
                                        color: root.textColor
                                        font.pixelSize: root.scaleUnit * 0.8
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Nur der Wirt des Pools -- der Benutzername enthaelt beim
                    // Solomining die Auszahlungsadresse und wird nirgends angezeigt.
                    text: root.one
                        ? [root.one.model, root.one.version, root.one.pool].filter(function (x) {
                              return !!x;
                          }).join(" · ")
                        : ""
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }
            }

            // ------------------------------------------------------- Verlauf
            MinerChart {
                width: parent.width
                height: root.scaleUnit * 4.2
                visible: root.showChart && root.one !== null && root.roomForChart
                         && (root.oneHist.hr || []).length > 1
                hist: root.oneHist
                lineColor: root.accentColor
                dimColor: root.dimColor
                labelSize: root.scaleUnit * 0.5
            }

            // ------------------------------------------ Rechenwerke einzeln
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.15
                visible: root.one !== null && (root.one.domains || []).length > 0
                         && root.roomForChart && root.showDomains

                Text {
                    // Der Chip ist intern in Hash-Domaenen geteilt (beim BM1370
                    // vier). Die Einzelmessungen rauschen um ueber zehn Prozent --
                    // gezeigt wird deshalb der geglaettete Wert, sonst sieht
                    // Rauschen wie ein Defekt aus.
                    text: root.one && root.one.domainSamples
                        ? Tr.t("miner.domainsAvg", root.lang,
                               Math.round(root.one.domainSamples * 5 / 60 * 10) / 10)
                        : Tr.t("miner.domains", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Row {
                    width: parent.width
                    spacing: root.scaleUnit * 0.25

                    Repeater {
                        model: root.one ? (root.one.domainsAvg || root.one.domains) : []

                        Rectangle {
                            id: dom

                            required property var modelData
                            required property int index

                            readonly property var vals: root.one.domainsAvg || root.one.domains || []

                            width: (root.width * 0.9 - root.scaleUnit * 0.75) / Math.max(1, dom.vals.length)
                            height: root.scaleUnit * 0.95
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.06)

                            Rectangle {
                                // Anteil am staerksten Rechenwerk -- so sieht man
                                // sofort, wenn eines abfaellt.
                                width: parent.width * Math.max(0.05, Math.min(1,
                                    dom.modelData / Math.max.apply(null, dom.vals)))
                                height: parent.height
                                radius: parent.radius
                                color: root.accentColor
                                opacity: 0.75
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(dom.modelData) + " GH/s"
                                color: root.textColor
                                font.pixelSize: root.scaleUnit * 0.5
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------- Bestenliste
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.12
                visible: root.showBoard && root.one !== null && root.roomForBoard
                         && (root.one.scoreboard || []).length > 0

                Text {
                    text: Tr.t("miner.bestList", root.lang)
                    color: root.dimColor
                    font.pixelSize: root.scaleUnit * 0.55
                }

                Repeater {
                    model: root.one ? (root.one.scoreboard || []).slice(0, 5) : []

                    Row {
                        id: sbRow

                        required property var modelData
                        required property int index

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Text {
                            width: root.scaleUnit * 1.2
                            text: (sbRow.index + 1) + "."
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: root.big(sbRow.modelData.diff)
                            color: sbRow.index === 0 ? root.accentColor : root.textColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: root.netDiff > 0
                                ? "1 zu " + root.big(root.netDiff / sbRow.modelData.diff)
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }

                        Text {
                            text: sbRow.modelData.time
                                ? new Date(sbRow.modelData.time * 1000).toLocaleDateString(Qt.locale("de_DE"))
                                : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.58
                        }
                    }
                }
            }

            // ------------------------------------------------ Geraete einzeln
            Column {
                width: parent.width
                spacing: root.scaleUnit * 0.2

                visible: root.one === null

                Repeater {
                    model: root.miners

                    Row {
                        id: line

                        required property var modelData

                        width: parent.width
                        spacing: root.scaleUnit * 0.5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.scaleUnit * 0.32
                            height: width
                            radius: width / 2
                            color: line.modelData.online ? root.goodColor : root.badColor
                        }

                        Text {
                            width: root.scaleUnit * 7
                            elide: Text.ElideRight
                            text: line.modelData.name || line.modelData.id
                            color: root.textColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            width: root.scaleUnit * 4
                            text: line.modelData.online ? root.big(line.modelData.hashRate, "H/s") : "aus"
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            visible: line.modelData.online && line.modelData.temp !== undefined
                                     && line.modelData.temp !== null
                            width: root.scaleUnit * 2.4
                            text: line.modelData.temp !== undefined && line.modelData.temp !== null
                                ? Math.round(line.modelData.temp) + " °C" : ""
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }

                        Text {
                            visible: line.modelData.online
                            text: root.span(line.modelData.uptime)
                            color: root.dimColor
                            font.pixelSize: root.scaleUnit * 0.62
                        }
                    }
                }
            }
        }
    }
}
