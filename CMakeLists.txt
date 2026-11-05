cmake_minimum_required(VERSION 3.21)

project(FreeSSM LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

option(FREESSM_USE_SYSTEM_TINYXML2 "Use an installed tinyxml2 instead of the bundled copy" OFF)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Widgets PrintSupport LinguistTools)
qt_standard_project_setup()

# The .ui forms live in ui/. AUTOUIC looks them up by basename from this list.
set(CMAKE_AUTOUIC_SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/ui")

set(FREESSM_SOURCES
    src/main.cpp
    src/FreeSSM.cpp
    src/CmdLine.cpp
    src/EngineDialog.cpp
    src/TransmissionDialog.cpp
    src/ABSdialog.cpp
    src/CruiseControlDialog.cpp
    src/AirConDialog.cpp
    src/Preferences.cpp
    src/About.cpp
    src/FSSMdialogs.cpp
    src/ActuatorTestDlg.cpp
    src/AbstractDiagInterface.cpp
    src/ATcommandControlledDiagInterface.cpp
    src/SerialPassThroughDiagInterface.cpp
    src/J2534DiagInterface.cpp
    src/J2534misc.cpp
    src/SSMP1communication.cpp
    src/SSMP1communication_procedures.cpp
    src/SSMP1base.cpp
    src/SSMP2communication.cpp
    src/SSMP2communication_core.cpp
    src/AbstractSSMcommunication.cpp
    src/SSMprotocol.cpp
    src/SSMprotocol1.cpp
    src/SSMprotocol2.cpp
    src/AddMBsSWsDlg.cpp
    src/ControlUnitDialog.cpp
    src/CUinfo_Engine.cpp
    src/CUinfo_Transmission.cpp
    src/CUinfo_simple.cpp
    src/CUcontent_DCs_abstract.cpp
    src/CUcontent_DCs_engine.cpp
    src/CUcontent_DCs_twoMemories.cpp
    src/CUcontent_DCs_stopCodes.cpp
    src/CUcontent_MBsSWs.cpp
    src/CUcontent_MBsSWs_tableView.cpp
    src/CUcontent_Adjustments.cpp
    src/CUcontent_sysTests.cpp
    src/DiagInterfaceStatusBar.cpp
    src/SSMDefinitionsInterface.cpp
    src/SSMLegacyDefinitionsInterface.cpp
    src/SSMFlagbyteDefinitionsInterface.cpp
    src/SSMFlagbyteDefinitions_SysDescriptions.cpp
    src/SSMFlagbyteDefinitions_en.cpp
    src/SSMFlagbyteDefinitions_de.cpp
    src/SSMFlagbyteDefinitions_tr.cpp
    src/SSMCUdata.cpp
    src/ClearMemoryDlg.cpp
    src/libFSSM.cpp
    src/tinyxml2/tinyxml2.cpp
)

set(FREESSM_HEADERS
    src/FreeSSM.h
    src/Languages.h
    src/CmdLine.h
    src/EngineDialog.h
    src/TransmissionDialog.h
    src/ABSdialog.h
    src/CruiseControlDialog.h
    src/AirConDialog.h
    src/Preferences.h
    src/About.h
    src/FSSMdialogs.h
    src/ActuatorTestDlg.h
    src/AbstractDiagInterface.h
    src/ATcommandControlledDiagInterface.h
    src/SerialPassThroughDiagInterface.h
    src/J2534DiagInterface.h
    src/J2534.h
    src/J2534misc.h
    src/SSMP1communication.h
    src/SSMP1communication_procedures.h
    src/SSMP1base.h
    src/SSMP2communication.h
    src/SSMP2communication_core.h
    src/AbstractSSMcommunication.h
    src/SSMprotocol.h
    src/SSMprotocol1.h
    src/SSMprotocol2.h
    src/AddMBsSWsDlg.h
    src/ControlUnitDialog.h
    src/CUinfo_abstract.h
    src/CUinfo_Engine.h
    src/CUinfo_Transmission.h
    src/CUinfo_simple.h
    src/CUcontent_DCs_abstract.h
    src/CUcontent_DCs_engine.h
    src/CUcontent_DCs_twoMemories.h
    src/CUcontent_DCs_stopCodes.h
    src/CUcontent_MBsSWs.h
    src/CUcontent_MBsSWs_tableView.h
    src/CUcontent_Adjustments.h
    src/CUcontent_sysTests.h
    src/DiagInterfaceStatusBar.h
    src/SSMDefinitionsInterface.h
    src/SSMLegacyDefinitionsInterface.h
    src/SSMFlagbyteDefinitionsInterface.h
    src/SSMFlagbyteDefinitions_SysDescriptions.h
    src/SSMFlagbyteDefinitions_en.h
    src/SSMFlagbyteDefinitions_de.h
    src/SSMFlagbyteDefinitions_tr.h
    src/SSMCUdata.h
    src/ClearMemoryDlg.h
    src/libFSSM.h
    src/tinyxml2/tinyxml2.h
)

set(FREESSM_FORMS
    ui/FreeSSM.ui
    ui/ControlUnitDialog.ui
    ui/CUcontent_DCs_engine.ui
    ui/CUcontent_DCs_twoMemories.ui
    ui/CUcontent_DCs_stopCodes.ui
    ui/CUcontent_MBsSWs.ui
    ui/CUcontent_MBsSWs_tableView.ui
    ui/CUcontent_Adjustments.ui
    ui/CUcontent_sysTests.ui
    ui/AddMBsSWsDlg.ui
    ui/CUinfo_Engine.ui
    ui/CUinfo_Transmission.ui
    ui/CUinfo_simple.ui
    ui/Preferences.ui
    ui/About.ui
    ui/ActuatorTestDlg.ui
)

if(WIN32)
    set(FREESSM_PLATFORM_SOURCES src/windows/serialCOM.cpp src/windows/TimeM.cpp src/windows/J2534_API.cpp)
    set(FREESSM_PLATFORM_HEADERS src/windows/serialCOM.h src/windows/TimeM.h src/windows/J2534_API.h)
    set(FREESSM_PLATFORM_LIBS ws2_32)
else()
    set(FREESSM_PLATFORM_SOURCES src/linux/serialCOM.cpp src/linux/TimeM.cpp src/linux/J2534_API.cpp)
    set(FREESSM_PLATFORM_HEADERS src/linux/serialCOM.h src/linux/TimeM.h src/linux/J2534_API.h)
    set(FREESSM_PLATFORM_LIBS ${CMAKE_DL_LIBS})
endif()

if(FREESSM_USE_SYSTEM_TINYXML2)
    find_package(tinyxml2 10 REQUIRED)
else()
    add_library(tinyxml2 STATIC src/tinyxml2/tinyxml2.cpp src/tinyxml2/tinyxml2.h)
    target_include_directories(tinyxml2 SYSTEM PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
    set_target_properties(tinyxml2 PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()

qt_add_executable(FreeSSM WIN32 MACOSX_BUNDLE
    ${FREESSM_SOURCES} ${FREESSM_HEADERS} ${FREESSM_FORMS}
    ${FREESSM_PLATFORM_SOURCES} ${FREESSM_PLATFORM_HEADERS}
    resources/FreeSSM.qrc
)

target_include_directories(FreeSSM PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/src" "${CMAKE_CURRENT_SOURCE_DIR}/src/tinyxml2")

target_link_libraries(FreeSSM PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::PrintSupport tinyxml2 ${FREESSM_PLATFORM_LIBS})

if(MSVC)
    target_compile_options(FreeSSM PRIVATE /W4)
else()
    target_compile_options(FreeSSM PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()

qt_add_translations(FreeSSM TS_FILES FreeSSM_en.ts FreeSSM_de.ts FreeSSM_tr.ts RESOURCE_PREFIX "/i18n")

# Flat "application directory" install: the app resolves background.png, fonts,
# definitions/, doc/ and the .qm files relative to QCoreApplication::applicationDirPath().
if(NOT DEFINED FREESSM_INSTALL_APPDIR)
    set(FREESSM_INSTALL_APPDIR "." CACHE PATH "Install directory of the FreeSSM application bundle")
endif()

install(TARGETS FreeSSM RUNTIME DESTINATION ${FREESSM_INSTALL_APPDIR} BUNDLE DESTINATION .)
install(FILES background.png LiberationSans-Bold.ttf LiberationSans-BoldItalic.ttf
              LiberationSans-Italic.ttf LiberationSans-Regular.ttf
        DESTINATION ${FREESSM_INSTALL_APPDIR})
install(DIRECTORY definitions/ DESTINATION ${FREESSM_INSTALL_APPDIR}/definitions)
install(DIRECTORY doc/ DESTINATION ${FREESSM_INSTALL_APPDIR}/doc)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/FreeSSM_en.qm ${CMAKE_CURRENT_BINARY_DIR}/FreeSSM_de.qm
              ${CMAKE_CURRENT_BINARY_DIR}/FreeSSM_tr.qm
        DESTINATION ${FREESSM_INSTALL_APPDIR})
