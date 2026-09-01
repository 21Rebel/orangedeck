// Desktop-Widget: dieselbe Ansicht, frei platzier- und skalierbar.
import QtQuick
import qs.Common

Item {
    id: root

    property var pluginService: null
    property string pluginId: "bitcoinFeed"
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
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        feed: feedState
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
}
