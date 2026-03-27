cmake_minimum_required(VERSION 3.16)

project(RealAmadeusPC VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Widgets Multimedia QuickEffects Concurrent)
find_package(OpenGL REQUIRED)

qt_standard_project_setup(REQUIRES 6.8)

set(CUBISM_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/CubismSdkForNative-5-r.4.1")
set(CUBISM_CORE_DIR "${CUBISM_SDK_DIR}/Core")
set(CUBISM_FRAMEWORK_DIR "${CUBISM_SDK_DIR}/Framework/src")
set(CUBISM_GLEW_DIR "${CUBISM_SDK_DIR}/Samples/OpenGL/thirdParty/glew")

set(APP_ICON_RESOURCE "")
if (WIN32)
    set(APP_ICON_RESOURCE "resources/app_icon.rc")
endif()

qt_add_executable(appRealAmadeusPC
    main.cpp
    src/appsettings.cpp
    src/appsettings.h
    src/memorymanager.cpp
    src/memorymanager.h
    src/aiservice.cpp
    src/aiservice.h
    src/live2ditem.cpp
    src/live2ditem.h
    src/amadeuslive2dmodel.cpp
    src/amadeuslive2dmodel.h
    ${APP_ICON_RESOURCE}
)

file(GLOB_RECURSE CUBISM_FRAMEWORK_SOURCES "${CUBISM_FRAMEWORK_DIR}/*.cpp")
list(FILTER CUBISM_FRAMEWORK_SOURCES EXCLUDE REGEX "Rendering/D3D.*|Rendering/Metal.*|Rendering/Vulkan.*")
target_sources(appRealAmadeusPC PRIVATE ${CUBISM_FRAMEWORK_SOURCES})

add_subdirectory("${CUBISM_GLEW_DIR}/build/cmake" "${CMAKE_CURRENT_BINARY_DIR}/glew")

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
target_include_directories(appRealAmadeusPC PRIVATE
    ${CUBISM_FRAMEWORK_DIR}
    ${CUBISM_CORE_DIR}/include
    ${CUBISM_GLEW_DIR}/include
)

target_compile_definitions(appRealAmadeusPC PRIVATE
    GLEW_STATIC
    REALAMADEUS_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}"
)

set(CUBISM_CORE_IMPORT_LIB "")
set(CUBISM_CORE_RUNTIME_LIB "")

if (WIN32)
    if (MINGW)
        message(FATAL_ERROR "Windows + Live2D Cubism Core is supported only with MSVC. Please use an MSVC Qt kit.")
    endif()

    target_compile_definitions(appRealAmadeusPC PRIVATE CSM_TARGET_WIN_GL)

    # CSM_CORE_WIN32_DLL enables __stdcall and is required only for 32-bit Windows DLL usage.
    if (CMAKE_SIZEOF_VOID_P EQUAL 4)
        target_compile_definitions(appRealAmadeusPC PRIVATE CSM_CORE_WIN32_DLL)
    endif()

    set(CUBISM_CORE_IMPORT_LIB "${CUBISM_CORE_DIR}/dll/windows/x86_64/Live2DCubismCore.lib")
    set(CUBISM_CORE_RUNTIME_LIB "${CUBISM_CORE_DIR}/dll/windows/x86_64/Live2DCubismCore.dll")
elseif (APPLE)
    target_compile_definitions(appRealAmadeusPC PRIVATE CSM_TARGET_MAC_GL)

    set(CUBISM_ARCH_SUBDIR "x86_64")
    if (CMAKE_OSX_ARCHITECTURES MATCHES "arm64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        set(CUBISM_ARCH_SUBDIR "arm64")
    endif()

    set(CUBISM_CORE_IMPORT_LIB "${CUBISM_CORE_DIR}/lib/macos/${CUBISM_ARCH_SUBDIR}/libLive2DCubismCore.a")
    set(CUBISM_CORE_RUNTIME_LIB "${CUBISM_CORE_DIR}/dll/macos/libLive2DCubismCore.dylib")
elseif (UNIX)
    target_compile_definitions(appRealAmadeusPC PRIVATE CSM_TARGET_LINUX_GL)

    set(CUBISM_LINUX_PREFIX "linux/x86_64")
    if (CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        set(CUBISM_LINUX_PREFIX "experimental/linux/ARM64")
    endif()

    set(CUBISM_CORE_IMPORT_LIB "${CUBISM_CORE_DIR}/lib/${CUBISM_LINUX_PREFIX}/libLive2DCubismCore.a")
    set(CUBISM_CORE_RUNTIME_LIB "${CUBISM_CORE_DIR}/dll/${CUBISM_LINUX_PREFIX}/libLive2DCubismCore.so")
endif()

if (NOT EXISTS "${CUBISM_CORE_IMPORT_LIB}")
    message(FATAL_ERROR "Live2D Cubism Core library not found for this platform: ${CUBISM_CORE_IMPORT_LIB}")
endif()

if (MINGW OR CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(appRealAmadeusPC PRIVATE "-fpermissive")
endif()

set_target_properties(appRealAmadeusPC PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appRealAmadeusPC
    PRIVATE Qt6::Quick Qt6::Network Qt6::Widgets Qt6::Multimedia Qt6::QuickEffects Qt6::Concurrent
            "${CUBISM_CORE_IMPORT_LIB}"
            glew_s
            OpenGL::GL
)

add_custom_command(TARGET appRealAmadeusPC POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CUBISM_CORE_RUNTIME_LIB}"
    $<TARGET_FILE_DIR:appRealAmadeusPC>
    COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:appRealAmadeusPC>/FrameworkShaders"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CUBISM_SDK_DIR}/Framework/src/Rendering/OpenGL/Shaders/Standard"
    "$<TARGET_FILE_DIR:appRealAmadeusPC>/FrameworkShaders"
    COMMAND ${CMAKE_COMMAND} -E make_directory
    "$<TARGET_FILE_DIR:appRealAmadeusPC>/resources/models/AmadeusKurisu5.0"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_CURRENT_SOURCE_DIR}/../RealAmadeusUnity/Assets/AmadeusKurisu5.0/reama5.0"
    "$<TARGET_FILE_DIR:appRealAmadeusPC>/resources/models/AmadeusKurisu5.0/reama5.0"
)

if(WIN32)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${Qt6_DIR}/../../../bin")
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET appRealAmadeusPC POST_BUILD
            COMMAND "${WINDEPLOYQT_EXECUTABLE}" --dir "$<TARGET_FILE_DIR:appRealAmadeusPC>" "$<TARGET_FILE:appRealAmadeusPC>"
            COMMENT "Deploying Qt runtime dependencies"
        )
    endif()
endif()

include(GNUInstallDirs)
install(TARGETS appRealAmadeusPC
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
