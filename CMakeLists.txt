# Eigenstaendige Qt-Anwendung.
#
# **Diese Datei liegt in der Wurzel und nicht in `app/`**, und das ist kein
# Geschmack: die geteilten QML-Dateien liegen unter `ui/qml/`. Von `app/` aus
# heissen sie `../ui/qml/...`, und Qt baut daraus den Namen des
# Zwischenverzeichnisses fuer den QML-Puffer. Unter Linux wird das `..`
# stillschweigend zu `_`, unter Windows nicht:
#
#     ninja: error: mkdir(.rcc/qmlcache/orangedeck-app_../ui): No such file
#
# Am 04.09.2026 im ersten CI-Lauf aufgeschlagen. **Qt empfiehlt ausdruecklich,
# QML-Dateien innerhalb des Modulverzeichnisses zu halten** -- von hier aus
# heissen sie `ui/qml/...` und die Frage stellt sich nicht mehr.
#
# Gebaut wird also aus der Wurzel:  cmake -S . -B build
cmake_minimum_required(VERSION 3.21)
project(orangedeck-app VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick)
qt_standard_project_setup(REQUIRES 6.5)

# Freiwillig: damit wird aus dem Fenster auf Wunsch eine Layer-Shell-Flaeche
# (`--layer`), also ein Desktop-Widget oder eine Leiste. Fehlt die Bibliothek,
# faellt nur dieser Schalter weg -- unter Android gibt es sie ohnehin nicht.
if(NOT ANDROID)
    find_package(LayerShellQt QUIET)
endif()

# Fuer den Direktbezug (DirectFeed.qml, `import QtWebSockets`). Freiwillig:
# ohne das Modul faellt nur diese Betriebsart aus, der Dienst traegt weiter.
# Verlinkt wird es trotzdem, wo es da ist -- unter Android packt
# androiddeployqt nur mit, was auch gebraucht wird.
find_package(Qt6 QUIET COMPONENTS WebSockets)

# **Die ABI-Liste muss stehen, bevor das Ziel angelegt wird.** Danach ist sie
# fuer Qt leer ("The list of Android ABIs is empty"), und die Folgefehler
# lesen sich ganz anders ("not a valid android executable target"), weil aus
# dem Ziel dann eine gewoehnliche ausfuehrbare Datei statt einer Bibliothek
# wird. Der alte Baubaum hatte den Wert nur zufaellig im Puffer stehen.
if(ANDROID AND NOT QT_ANDROID_ABIS)
    set(QT_ANDROID_ABIS "${ANDROID_ABI}")
endif()

qt_add_executable(orangedeck-app app/src/main.cpp)

# Die geteilten Dateien liegen ausserhalb dieses Verzeichnisses. Ohne
# ausdruecklichen Alias landen sie mit ihrem relativen Pfad im Ressourcenbaum,
# und dann findet FeedCanvas.qml sein "mondrian.js" nicht mehr.
set(SHARED_QML
    ui/qml/FeedState.qml
    ui/qml/DirectFeed.qml
    ui/qml/FeedCanvas.qml
    ui/qml/FeedPanel.qml
    ui/qml/FrostedPanel.qml
    ui/qml/ClockView.qml
    ui/qml/MinerView.qml
    ui/qml/MinerChart.qml
    ui/qml/PriceChart.qml
    ui/qml/MarketView.qml
    ui/qml/MarketLiq.qml
    ui/qml/MarketHeat.qml
    ui/qml/DropDown.qml
    ui/qml/ViewTabs.qml
    ui/qml/FeedTabs.qml
    ui/qml/InfoPopup.qml
    ui/qml/ExplorerView.qml
    ui/qml/TxFlow.qml
    ui/qml/CopyButton.qml
    ui/qml/BlockChain.qml
    ui/qml/BlockCard.qml
    ui/qml/BlockTiles.qml
    ui/qml/ProjectedBlock.qml
    ui/qml/TileGoggles.qml
    ui/qml/WatchView.qml
    ui/qml/TxList.qml
    ui/qml/BlockHistory.qml
    ui/qml/SettingsView.qml
    ui/qml/ExplorerHome.qml
    ui/qml/MainPanels.qml
    ui/qml/search.js
    ui/qml/txtype.js
    ui/qml/money.js
    ui/qml/strings.js
    ui/qml/mondrian.js
    ui/qml/colors.js
    ui/qml/fonts.js
)
# Main.qml gehoert dazu: liegt es im Ressourcenbaum unter qml/, waehrend die
# geteilten Dateien in der Modulwurzel sitzen, findet es sie nicht mehr
# ("FeedState is not a type"). Die Aliasse muessen VOR qt_add_qml_module
# gesetzt werden, danach wirken sie nicht mehr.
foreach(f ${SHARED_QML} app/qml/Main.qml)
    get_filename_component(n "${f}" NAME)
    set_source_files_properties("${f}" PROPERTIES QT_RESOURCE_ALIAS "${n}")
endforeach()

qt_add_qml_module(orangedeck-app
    URI OrangeDeck
    VERSION 1.0
    QML_FILES app/qml/Main.qml ${SHARED_QML}
)

# **Ohne das gibt es auf Windows ein Konsolenfenster neben der Anwendung und
# auf macOS gar kein .app-Buendel** -- dann laesst sie sich dort weder
# doppelklicken noch mit `macdeployqt` packen. Unter Linux und Android sind
# beide Eigenschaften wirkungslos, sie kosten also nichts.
#
# Aufgefallen am 04.09.2026 beim Schreiben der Bauplaene fuer Windows und
# macOS -- auf diesem Rechner konnte es nie stoeren.
set_target_properties(orangedeck-app PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE ON
)

target_link_libraries(orangedeck-app PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)

# **Auf Android muss OpenSSL mit ins APK.** Qt liefert es dort nicht mit, und
# ohne es meldet das Geraet nur "No functional TLS backend was found" -- die
# App ist dann vollstaendig funktionslos, weil mempool.space nur https und wss
# spricht. Auf dem Schreibtisch faellt das nicht auf: dort wird das
# System-OpenSSL benutzt.
#
# Gebaut wird es mit `tools/openssl-android.sh` aus dem offiziellen Quelltext,
# Pruefsumme gegen die Angabe des Projekts. Das Ergebnis liegt ausserhalb des
# Repos; fehlt es, wird trotzdem gebaut -- nur eben ohne TLS, und diese
# Meldung sagt es.
if(ANDROID)
    set(_ossl "${CMAKE_CURRENT_SOURCE_DIR}/build-openssl-android/${ANDROID_ABI}")
    # Die Namen sind nicht frei waehlbar: Qts TLS-Plugin sucht auf Android
    # nach `libssl_3.so` und `libcrypto_3.so` (Vorgabe von
    # `ANDROID_OPENSSL_SUFFIX`). Heissen sie anders, findet es sie nicht --
    # auch wenn sie im APK liegen.
    if(EXISTS "${_ossl}/libssl_3.so" AND EXISTS "${_ossl}/libcrypto_3.so")
        set_property(TARGET orangedeck-app APPEND PROPERTY QT_ANDROID_EXTRA_LIBS
            "${_ossl}/libcrypto_3.so" "${_ossl}/libssl_3.so")
        message(STATUS "orangedeck: OpenSSL fuer ${ANDROID_ABI} wird mitgepackt")
    else()
        message(WARNING
            "orangedeck: kein OpenSSL fuer ${ANDROID_ABI} -- das APK bekommt "
            "KEIN TLS und ist auf dem Geraet unbrauchbar. Bauen mit:\n"
            "    tools/openssl-android.sh ${ANDROID_ABI}")
    endif()
endif()

if(Qt6WebSockets_FOUND)
    target_link_libraries(orangedeck-app PRIVATE Qt6::WebSockets)
    message(STATUS "orangedeck: QtWebSockets vorhanden, Direktbezug steht bereit")
else()
    message(STATUS "orangedeck: ohne QtWebSockets gebaut, nur Betrieb ueber den Dienst")
endif()

if(LayerShellQt_FOUND)
    target_compile_definitions(orangedeck-app PRIVATE ORANGEDECK_LAYERSHELL)
    target_link_libraries(orangedeck-app PRIVATE LayerShellQt::Interface)
    message(STATUS "orangedeck: Layer-Shell vorhanden, --layer steht bereit")
else()
    message(STATUS "orangedeck: ohne Layer-Shell gebaut, --layer fehlt")
endif()

include(GNUInstallDirs)
# Auf Android ist "orangedeck-app" keine ausfuehrbare Datei, sondern eine
# Bibliothek, die die Java-Huelle laedt -- `install(TARGETS)` verlangt dort
# ein LIBRARY-Ziel und bricht sonst schon beim Einrichten ab. Installiert wird
# unter Android ohnehin nichts: das Ergebnis ist das APK.
# **Nur dort, wo es ein freedesktop-System gibt.** Die .desktop-Datei und das
# Symbol im hicolor-Baum sind Linux-Begriffe; auf macOS kaeme dazu, dass ein
# `MACOSX_BUNDLE`-Ziel bei `install(TARGETS)` ein BUNDLE-Ziel verlangt und
# sonst schon beim Einrichten abbricht.
if(NOT ANDROID AND NOT APPLE AND NOT WIN32)
    install(TARGETS orangedeck-app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/app/store._21rebel.orangedeck.desktop
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/app/icons/store._21rebel.orangedeck.svg
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)
endif()
