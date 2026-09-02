// Desktop-Widget: **jede Ansicht**, frei platzier- und skalierbar.
//
// DMS legt jede Instanz eines Desktop-Widgets getrennt ab und reicht dem
// Bauteil einen instanzbezogenen `pluginService` durch (siehe
// DesktopPluginWrapper: `instanceScopedPluginService`). `loadPluginData` ist
// hier also **je Instanz** -- man kann denselben Feed dreimal aufs Desktop
// legen, einmal als Halde, einmal als BlockClock, einmal als Miner.
import QtQuick
import qs.Common

Item {
    id: root

    property var pluginService: null
    property string pluginId: "bitcoinFeed"
    // Von DMS gesetzt, wenn es eine Instanz ist
    property string instanceId: ""
    property var instanceData: null
    property bool editMode: false
    property real widgetWidth: 420
    property real widgetHeight: 300

    property real minWidth: 180
    property real minHeight: 120
    property real defaultWidth: 520
    property real defaultHeight: 380

    property int bgOpacity: pluginService ? pluginService.loadPluginData(pluginId, "desktopOpacity", 70) : 70
    property int tileDensity: pluginService ? pluginService.loadPluginData(pluginId, "tileDensity", 100) : 100
    property string colorMode: pluginService ? pluginService.loadPluginData(pluginId, "colorMode", "age") : "age"
    property string sizeMode: pluginService ? pluginService.loadPluginData(pluginId, "sizeMode", "value") : "value"
    property bool showInfo: pluginService ? pluginService.loadPluginData(pluginId, "showInfo", true) : true
    property bool showLegend: pluginService ? pluginService.loadPluginData(pluginId, "showLegend", true) : true
    // Welche Ansicht dieses Widget zeigt: feed | clock | miner | explorer
    property string widgetView: pluginService ? pluginService.loadPluginData(pluginId, "widgetView", "feed") : "feed"
    property string lang: pluginService ? pluginService.loadPluginData(pluginId, "lang", "de") : "de"
    property string currency: pluginService ? pluginService.loadPluginData(pluginId, "currency", "eur") : "eur"
    property string bigFieldsRaw: pluginService ? pluginService.loadPluginData(pluginId, "bigFieldsRaw", "height") : "height"
    property int bigRotate: pluginService ? pluginService.loadPluginData(pluginId, "bigRotate", 0) : 0
    readonly property var bigFields: bigFieldsRaw.length ? bigFieldsRaw.split("|") : ["height"]

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId)
                return;
            root.bgOpacity = root.pluginService.loadPluginData(root.pluginId, "desktopOpacity", 70);
            root.tileDensity = root.pluginService.loadPluginData(root.pluginId, "tileDensity", 100);
            root.colorMode = root.pluginService.loadPluginData(root.pluginId, "colorMode", "age");
            root.sizeMode = root.pluginService.loadPluginData(root.pluginId, "sizeMode", "value");
            root.showInfo = root.pluginService.loadPluginData(root.pluginId, "showInfo", true);
            root.showLegend = root.pluginService.loadPluginData(root.pluginId, "showLegend", true);
            root.widgetView = root.pluginService.loadPluginData(root.pluginId, "widgetView", "feed");
            root.lang = root.pluginService.loadPluginData(root.pluginId, "lang", "de");
            root.currency = root.pluginService.loadPluginData(root.pluginId, "currency", "eur");
            root.bigFieldsRaw = root.pluginService.loadPluginData(root.pluginId, "bigFieldsRaw", "height");
            root.bigRotate = root.pluginService.loadPluginData(root.pluginId, "bigRotate", 0);
        }
    }

    FeedState {
        id: feedState

        pollMs: 500
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: Math.max(0, Math.min(100, root.bgOpacity)) / 100
        border.width: root.editMode ? 2 : 0
        border.color: root.editMode ? Theme.primary : "transparent"
    }

    FeedPanel {
        visible: root.widgetView === "feed"
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        feed: feedState
        lang: root.lang
        currency: root.currency
        density: Math.max(0.5, root.tileDensity / 100)
        colorMode: root.colorMode
        sizeMode: root.sizeMode
        infoVisible: root.showInfo
        legendVisible: root.showLegend
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
        lineColor: Theme.outlineMedium
        baseFont: Theme.fontSizeSmall
    }

    ClockView {
        visible: root.widgetView === "clock"
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        feed: feedState
        lang: root.lang
        currency: root.currency
        bigFields: root.bigFields
        bigRotate: root.bigRotate
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
    }

    MinerView {
        visible: root.widgetView === "miner"
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        feed: feedState
        lang: root.lang
        // Auf dem Desktop stellt niemand Knoepfe -- das Widget ist zum
        // Ansehen da, nicht zum Bedienen.
        showActions: false
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
    }

    ExplorerView {
        visible: root.widgetView === "explorer"
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        feed: feedState
        lang: root.lang
        currency: root.currency
        textColor: Theme.surfaceText
        dimColor: Theme.surfaceVariantText
        accentColor: Theme.primary
    }
}
