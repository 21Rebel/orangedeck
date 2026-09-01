# Eigenstaendige Qt-Anwendung. Dieselben QML-Dateien wie das DMS-Plugin --
# ui/qml/ wird hier nur zusaetzlich in ein QML-Modul gepackt, nicht kopiert.
cmake_minimum_required(VERSION 3.21)
project(btcfeed-app VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(btcfeed-app src/main.cpp)

# Die geteilten Dateien liegen ausserhalb dieses Verzeichnisses. Ohne
# ausdruecklichen Alias landen sie mit ihrem relativen Pfad im Ressourcenbaum,
# und dann findet FeedCanvas.qml sein "mondrian.js" nicht mehr.
set(SHARED_QML
    ../ui/qml/FeedState.qml
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
    ../ui/qml/search.js
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

include(GNUInstallDirs)
install(TARGETS btcfeed-app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/dev.21rebel.btcfeed.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
