import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "bitcoinFeed"

    SelectionSetting {
        settingKey: "colorMode"
        label: "Farbe nach"
        description: "Alter: orange beim Eintreffen, blau nach 60 Sekunden (wie im Original). Gebühr: türkis bis violett nach sat/vByte."
        options: [
            {label: "Alter", value: "age"},
            {label: "Gebührenrate", value: "fee"}
        ]
        defaultValue: "age"
    }

    SelectionSetting {
        settingKey: "sizeMode"
        label: "Größe nach"
        description: "Wert: jede Rasterstufe entspricht dem Zehnfachen an Ausgabewert. vBytes: Fläche nach Transaktionsgröße."
        options: [
            {label: "Ausgabewert", value: "value"},
            {label: "vBytes", value: "vbytes"}
        ]
        defaultValue: "value"
    }

    ToggleSetting {
        settingKey: "showInfo"
        label: "Blockangaben"
        description: "Höhe, Zeit, Gesamtwert, Größe und Ø-Gebühr des letzten Blocks"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showLegend"
        label: "Legende"
        description: "Größen- und Farbskala am rechten Rand"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "desktopOpacity"
        label: "Deckkraft Desktop-Widget"
        description: "Hintergrund des Desktop-Widgets"
        defaultValue: 70
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "tileDensity"
        label: "Kachelgröße"
        description: "Größer = weniger, dafür gröbere Kacheln"
        defaultValue: 100
        minimum: 60
        maximum: 250
        unit: "%"
    }
}
