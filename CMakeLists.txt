cmake_minimum_required(VERSION 3.16)

project(RealAmadeusPC VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Widgets Multimedia QuickEffects)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appRealAmadeusPC
    main.cpp
    src/appsettings.cpp
    src/appsettings.h
    src/memorymanager.cpp
    src/memorymanager.h
    src/aiservice.cpp
    src/aiservice.h
)

qt_add_qml_module(appRealAmadeusPC
    URI RealAmadeusPC
    QML_FILES
        qml/Main.qml
        qml/LoginPanel.qml
        qml/LoadingPanel.qml
        qml/ChatPanel.qml
        qml/MenuPanel.qml
        qml/ConfigPanel.qml
        qml/BackLogPanel.qml
        qml/StatusPanel.qml
        qml/ChangeLogPanel.qml
        qml/HelpPanel.qml
        qml/ConfirmationDialog.qml
        qml/components/FadePanel.qml
        qml/SystemPanel.qml
    RESOURCES
        resources/images/Amadeus_BG.png
        resources/images/amadeus_logo_v3.png
        resources/images/amadeus_login_button_v2.png
        resources/images/RealAmadeus_Menu_BG_v3.jpg
        resources/images/Backlog.png
        resources/images/BacklogSelected.png
        resources/images/ChangeLog.png
        resources/images/ChangeLogSelected.png
        resources/images/Config.png
        resources/images/ConfigSelected.png
        resources/images/Help.png
        resources/images/HelpSelected.png
        resources/images/Status.png
        resources/images/StatusSelected.png
        resources/images/Menu.png
        resources/images/DownAllow.png
        "resources/fonts/Eurostile Condensed Bold.otf"
        resources/fonts/MateSC-Regular.ttf
        resources/fonts/DepartureMono-Regular.otf
        resources/fonts/LiberationSans.ttf
)

target_include_directories(appRealAmadeusPC PRIVATE src)

set_target_properties(appRealAmadeusPC PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appRealAmadeusPC
    PRIVATE Qt6::Quick Qt6::Network Qt6::Widgets Qt6::Multimedia Qt6::QuickEffects
)

include(GNUInstallDirs)
install(TARGETS appRealAmadeusPC
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
