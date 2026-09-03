// Der ganze Satz Ansichten mit der Reiterzeile darueber -- Feed, BlockClock,
// Miner, Explorer, Wallet, Einstellungen.
//
// **Einmal gebaut, dreimal benutzt**: im Dashboard-Tab von DMS, im Popout der
// Leisten-Pille und in der Kachel des Control Centers. Vorher stand der Satz
// nur im Dashboard-Tab; die beiden anderen zeigten allein den Feed und lasen
// vier von dreissig Einstellungen -- Sprache und Waehrung kamen dort nie an.
//
// Der Wirt haelt den Zustand, dieses Bauteil zeigt ihn nur:
//
//   opts          dieselbe Sammlung, die auch `SettingsView` liest
//   view          welche Ansicht gerade oben liegt
//   optRequested  "stell das bitte um" -- der Wirt legt es ab, wo er mag
//                 (QSettings im Fenster, Plugin-Ablage in DMS)
//   viewRequested dasselbe fuer den Reiter
//
// Nur `import QtQuick` -- damit laeuft es auch unter Android.
import QtQuick
import "strings.js" as Tr

Item {
    id: root

    property var feed: null
    // Sieht niemand hin, rechnet auch nichts
    property bool live: true
    property var opts: ({})
    // 0 Feed, 1 BlockClock, 2 Miner, 3 Explorer, 4 Wallet, 5 Einstellungen
    property int view: 0
    // Die Einstellungsseite blendet Deckkraft und Startansicht aus, wo das
    // Fenster nicht dem Programm gehoert.
    property bool windowedSettings: false
    // Im Dashboard stellt die Leiste oben rechts die Knoepfe des Miners --
    // dort kann sie nichts ueberdecken.
    property bool minerActions: true
    // Das Desktop-Widget zeigt **eine** Ansicht ohne Reiterzeile. Es benutzt
    // trotzdem dieses Bauteil, damit die Ansichten nur an einer Stelle
    // verdrahtet sind.
    property bool tabsVisible: true

    property color textColor: "#e6e0e9"
    property color dimColor: "#9a94a6"
    property color accentColor: "#f7931a"
    property color lineColor: "#2a2a38"
    // Untergrund fuer aufklappende Flaechen (Auswahlfelder). In DMS ist das
    // dessen eigene Flaechenfarbe -- damit traegt das Auswahlfeld dieselbe
    // Deckkraft wie die Einstellungen daneben, statt eine eigene zu erfinden.
    property color panelColor: "#16161f"
    property real baseFont: 13
    property real tabFont: 12
    property real gap: 8

    signal optRequested(string key, var value)
    signal viewRequested(int v)

    function o(key, def) {
        return root.opts[key] === undefined ? def : root.opts[key];
    }

    readonly property string lang: root.o("lang", "de")
    readonly property string currency: root.o("currency", "eur")
    readonly property bool walletEnabled: root.o("walletEnabled", false)
    // **Ein unsichtbares Element behaelt seine Hoehe.** Ohne die Abfrage
    // stuende im nackten Widget oben ein leerer Streifen in Reiterhoehe.
    readonly property real tabSpace: root.tabsVisible ? tabs.height + root.gap : 0

    // Zwei Reiter fallen im Direktbezug weg, und zwar nicht aus Bequemlichkeit:
    // der Miner steht im Heimnetz, die Wallet-Ableitung ist Rechenarbeit des
    // Dienstes. Ein Reiter, hinter dem nichts sein kann, ist schlimmer als
    // keiner.
    // 6 ist der Markt. Er steht hinter dem Explorer und **nur mit Dienst**:
    // die Boersenstroeme werden dort zu Kerzen verdichtet, im Direktbezug
    // gibt es niemanden, der das tut. Ein Reiter, hinter dem nichts sein
    // kann, ist schlimmer als keiner -- dieselbe Regel wie bei Miner und
    // Wallet.
    readonly property bool canMarket: root.feed && !root.feed.direkt

    readonly property var tabViews: {
        var v = [0, 1];
        if (root.feed && root.feed.canMiner)
            v.push(2);
        v.push(3);
        if (root.canMarket)
            v.push(6);
        if (root.walletEnabled && root.feed && root.feed.canWallet)
            v.push(4);
        v.push(5);
        return v;
    }

    readonly property var tabLabels: {
        var l = [Tr.t("tab.feed", root.lang), Tr.t("tab.clock", root.lang)];
        if (root.feed && root.feed.canMiner)
            l.push(Tr.t("tab.miner", root.lang));
        l.push(Tr.t("tab.explorer", root.lang));
        if (root.canMarket)
            l.push(Tr.t("tab.market", root.lang));
        if (root.walletEnabled && root.feed && root.feed.canWallet)
            l.push(Tr.t("tab.wallet", root.lang));
        l.push(Tr.t("tab.settings", root.lang));
        return l;
    }

    // Steht die Ansicht auf einem Reiter, den es gerade nicht gibt, zurueck auf
    // den Feed -- sonst bliebe eine leere Seite stehen.
    onTabViewsChanged: {
        if (root.tabsVisible && root.tabViews.indexOf(root.view) < 0)
            root.viewRequested(0);
    }

    ViewTabs {
        id: tabs

        anchors.left: parent.left
        anchors.top: parent.top
        visible: root.tabsVisible
        labels: root.tabLabels
        current: root.tabViews.indexOf(root.view)
        fontSize: root.tabFont
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        z: 30
        onPicked: function (i) {
            root.viewRequested(root.tabViews[i]);
        }
    }

    FeedPanel {
        id: halde

        visible: root.live && root.view === 0
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        currency: root.currency
        headerVisible: root.o("showHeader", true)
        footerVisible: root.o("showFooter", true)
        blockVisible: root.o("showBlock", true)
        rulerVisible: root.o("showRuler", true)
        infoVisible: root.o("showInfo", true)
        legendVisible: root.o("showLegend", true)
        frostedInfo: root.o("frosted", true)
        frostedBlur: root.o("frosted", true)
        density: root.o("density", 1)
        colorMode: root.o("colorMode", "age")
        sizeMode: root.o("sizeMode", "value")
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        baseFont: root.baseFont
        onColorModeRequested: function (m) {
            root.optRequested("colorMode", m);
        }
        onTxActivated: function (txid) {
            root.viewRequested(3);
            explorer.go("tx", txid);
        }
    }

    ClockView {
        visible: root.live && root.view === 1
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        currency: root.currency
        fields: root.o("clockFields", [])
        showBars: root.o("clockBars", true)
        showSpark: root.o("clockSpark", true)
        showTime: root.o("clockTime", false)
        showPrice: root.o("clockPrice", true)
        priceSpan: root.o("priceSpan", "30d")
        onPriceSpanRequested: function (sp) {
            root.optRequested("priceSpan", sp);
        }
        bigFields: root.o("bigFields", ["height"])
        bigRotate: root.o("bigRotate", 0)
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
    }

    MinerView {
        id: miner

        visible: root.live && root.view === 2
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        showActions: root.minerActions
        feed: root.feed
        lang: root.lang
        metricKeys: root.o("minerFields", [])
        showChart: root.o("minerChart", true)
        showDomains: root.o("minerDomains", true)
        showBoard: root.o("minerBoard", true)
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
    }

    ExplorerView {
        id: explorer

        visible: root.live && root.view === 3
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        currency: root.currency
        tileColorMode: root.o("tileColorMode", "fee")
        homeParts: root.o("explorerParts", [])
        homePanels: root.o("explorerPanels", [])
        trackProjected: root.o("explorerLive", true)
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        onTileColorModeRequested: function (m) {
            root.optRequested("tileColorMode", m);
        }
    }

    MarketView {
        visible: root.live && root.view === 6 && root.canMarket
        // Nur abfragen, wenn der Reiter auch offen ist -- jede Abfrage haelt
        // im Dienst die Boersenstroeme am Leben.
        live: visible
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        panelColor: root.panelColor
        range: root.o("marketRange", "24h")
        kind: root.o("marketKind", "candles")
        customSecs: root.o("marketSecs", 259200)
        crosshair: root.o("marketCross", true)
        showTape: root.o("marketTape", true)
        baseFont: root.baseFont
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        lineColor: root.lineColor
        onRangeRequested: function (r) {
            root.optRequested("marketRange", r);
        }
        onKindRequested: function (k) {
            root.optRequested("marketKind", k);
        }
        onCustomSecsRequested: function (sek) {
            root.optRequested("marketSecs", sek);
        }
    }

    WatchView {
        visible: root.live && root.view === 4 && root.walletEnabled
        // Nur nachfragen, wenn die Ansicht auch zu sehen ist
        live: visible
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        feed: root.feed
        lang: root.lang
        currency: root.currency
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        onTxPicked: function (txid) {
            root.viewRequested(3);
            explorer.go("tx", txid);
        }
        onAddressPicked: function (adr) {
            root.viewRequested(3);
            explorer.go("address", adr);
        }
    }

    SettingsView {
        visible: root.live && root.view === 5
        anchors.fill: parent
        anchors.topMargin: root.tabSpace
        opts: root.opts
        lang: root.lang
        windowed: root.windowedSettings
        textColor: root.textColor
        dimColor: root.dimColor
        accentColor: root.accentColor
        onChanged: function (key, value) {
            root.optRequested(key, value);
        }
    }

    // Die Blockanimation von Hand ausloesen -- das Fenster legt sie auf die
    // Taste b, zum Pruefen ohne zehn Minuten Wartezeit.
    function triggerBlockAnimation() {
        halde.triggerBlockAnimation();
    }

    // Der Miner traegt zwei Knoepfe, die im Dashboard nicht bei ihm, sondern in
    // der Leiste oben rechts sitzen. Damit der Wirt sie dort stellen kann,
    // reicht dieses Bauteil sie durch.
    readonly property string minerWebUrl: miner.webUrl

    function minerOpenWeb() {
        miner.openWeb();
    }

    function minerToggleInfo() {
        miner.toggleInfo();
    }

    // Von aussen ansteuerbar -- der Wirt kann von der Pille aus direkt in eine
    // Transaktion springen.
    function goExplorer(art, wert) {
        root.viewRequested(3);
        explorer.go(art, wert);
    }
}
