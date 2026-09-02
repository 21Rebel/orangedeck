# Eigenstaendige Qt-Anwendung. Dieselben QML-Dateien wie das DMS-Plugin --
# ui/qml/ wird hier nur zusaetzlich in ein QML-Modul gepackt, nicht kopiert.
cmake_minimum_required(VERSION 3.21)
project(btcfeed-app VERSION 0.1 LANGUAGES CXX)

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

qt_add_executable(btcfeed-app src/main.cpp)

# Die geteilten Dateien liegen ausserhalb dieses Verzeichnisses. Ohne
# ausdruecklichen Alias landen sie mit ihrem relativen Pfad im Ressourcenbaum,
# und dann findet FeedCanvas.qml sein "mondrian.js" nicht mehr.
set(SHARED_QML
    ../ui/qml/FeedState.qml
    ../ui/qml/DirectFeed.qml
    ../ui/qml/FeedCanvas.qml
    ../ui/qml/FeedPanel.qml
    ../ui/qml/FrostedPanel.qml
    ../ui/qml/ClockView.qml
    ../ui/qml/MinerView.qml
    ../ui/qml/MinerChart.qml
    ../ui/qml/ViewTabs.qml
    ../ui/qml/InfoPopup.qml
    ../ui/qml/ExplorerView.qml
    ../ui/qml/TxFlow.qml
    ../ui/qml/CopyButton.qml
    ../ui/qml/BlockChain.qml
    ../ui/qml/BlockCard.qml
    ../ui/qml/BlockTiles.qml
    ../ui/qml/ProjectedBlock.qml
    ../ui/qml/TileGoggles.qml
    ../ui/qml/WatchView.qml
    ../ui/qml/TxList.qml
    ../ui/qml/BlockHistory.qml
    ../ui/qml/SettingsView.qml
    ../ui/qml/ExplorerHome.qml
    ../ui/qml/MainPanels.qml
    ../ui/qml/search.js
    ../ui/qml/txtype.js
    ../ui/qml/money.js
    ../ui/qml/strings.js
    ../ui/qml/mondrian.js
    ../ui/qml/colors.js
)
# Main.qml gehoert dazu: liegt es im Ressourcenbaum unter qml/, waehrend die
# geteilten Dateien in der Modulwurzel sitzen, findet es sie nicht mehr
# ("FeedState is not a type"). Die Aliasse muessen VOR qt_add_qml_module
# gesetzt werden, danach wirken sie nicht mehr.
foreach(f ${SHARED_QML} qml/Main.qml)
    get_filename_component(n "${f}" NAME)
    set_source_files_properties("${f}" PROPERTIES QT_RESOURCE_ALIAS "${n}")
endforeach()

qt_add_qml_module(btcfeed-app
    URI BtcFeed
    VERSION 1.0
    QML_FILES qml/Main.qml ${SHARED_QML}
)

target_link_libraries(btcfeed-app PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)

if(Qt6WebSockets_FOUND)
    target_link_libraries(btcfeed-app PRIVATE Qt6::WebSockets)
    message(STATUS "btcfeed: QtWebSockets vorhanden, Direktbezug steht bereit")
else()
    message(STATUS "btcfeed: ohne QtWebSockets gebaut, nur Betrieb ueber den Dienst")
endif()

if(LayerShellQt_FOUND)
    target_compile_definitions(btcfeed-app PRIVATE BTCFEED_LAYERSHELL)
    target_link_libraries(btcfeed-app PRIVATE LayerShellQt::Interface)
    message(STATUS "btcfeed: Layer-Shell vorhanden, --layer steht bereit")
else()
    message(STATUS "btcfeed: ohne Layer-Shell gebaut, --layer fehlt")
endif()

include(GNUInstallDirs)
# Auf Android ist "btcfeed-app" keine ausfuehrbare Datei, sondern eine
# Bibliothek, die die Java-Huelle laedt -- `install(TARGETS)` verlangt dort
# ein LIBRARY-Ziel und bricht sonst schon beim Einrichten ab. Installiert wird
# unter Android ohnehin nichts: das Ergebnis ist das APK.
if(NOT ANDROID)
    install(TARGETS btcfeed-app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/store._21rebel.btcfeed.desktop
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/store._21rebel.btcfeed.svg
            DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)
endif()
