cmake_minimum_required(VERSION 3.21)
cmake_policy(SET CMP0091 NEW)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
project(StudioEvents LANGUAGES CXX)

if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "StudioEvents requires Windows MSVC x86. Configure with -A Win32.")
endif()
get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(multi_config)
    set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "Supported configurations" FORCE)
elseif(NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release)$")
    message(FATAL_ERROR "Select Debug or Release.")
endif()

include(cmake/Dependencies.cmake)
studioevents_prepare_dependencies()
include("${VC_LTL_Root}/VC-LTL helper for cmake.cmake")

# Include directories and definitions follow StudioEvents.vcxproj.
add_library(studioevents_settings INTERFACE)
target_compile_features(studioevents_settings INTERFACE cxx_std_20)
target_include_directories(studioevents_settings INTERFACE
    src
    "${METAHOOK_SOURCE_PATH}/include"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/cl_dll"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/common"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/engine"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/pm_shared"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/public"
    "${METAHOOK_SOURCE_PATH}/include/SourceSDK"
    "${METAHOOK_SOURCE_PATH}/include/SourceSDK/tier0"
    "${METAHOOK_SOURCE_PATH}/include/SourceSDK/tier1"
    "${METAHOOK_SOURCE_PATH}/include/SourceSDK/tier3"
    "${METAHOOK_SOURCE_PATH}/include/SourceSDK/vstdlib"
    "${METAHOOK_SOURCE_PATH}/include/Interface"
    ${STUDIOEVENTS_CAPSTONE_INCLUDE_DIRS}
)
target_compile_definitions(studioevents_settings INTERFACE
    WIN32 _WINDOWS _USRDLL _MBCS NO_MALLOC_OVERRIDE
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>)
target_compile_options(studioevents_settings INTERFACE /permissive
    $<$<CONFIG:Debug>:/W0>
    $<$<CONFIG:Release>:/W3>
    /wd4311 /wd4312 /wd4819 /wd4996)

include(cmake/Sources.cmake)
add_library(StudioEvents SHARED ${STUDIOEVENTS_SOURCES})
target_link_libraries(StudioEvents PRIVATE studioevents_settings)
target_compile_options(StudioEvents PRIVATE /MP /Zi)
target_link_options(StudioEvents PRIVATE /DEBUG /SUBSYSTEM:WINDOWS
    $<$<CONFIG:Debug>:/INCREMENTAL>
    $<$<CONFIG:Release>:/INCREMENTAL:NO>
    $<$<CONFIG:Release>:/OPT:REF>
    $<$<CONFIG:Release>:/OPT:ICF>)
set_target_properties(StudioEvents PROPERTIES INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)

install(TARGETS StudioEvents RUNTIME DESTINATION svencoop/metahook/plugins)
install(FILES "$<TARGET_PDB_FILE:StudioEvents>" DESTINATION svencoop/metahook/plugins)
install(DIRECTORY "${PROJECT_SOURCE_DIR}/assets/svencoop/studioevents" DESTINATION svencoop)

option(STUDIOEVENTS_SYNC_GAMEDATA "Download and prune StudioEvents' gamedata catalog before building" ON)
set(STUDIOEVENTS_GAMEDATA_DIR "${PROJECT_BINARY_DIR}/assets/svencoop/metahook/gamedata/studioevents" CACHE PATH "StudioEvents gamedata catalog directory")
if(STUDIOEVENTS_SYNC_GAMEDATA)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    add_custom_target(StudioEventsGameData
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/sync-gamedata.py"
            --manifest "${CMAKE_CURRENT_SOURCE_DIR}/scripts/manifests/studioevents.json"
            --target-dir "${STUDIOEVENTS_GAMEDATA_DIR}" --temp-root "${PROJECT_BINARY_DIR}/gamedata-sync"
        COMMENT "Synchronizing and validating StudioEvents gamedata"
        VERBATIM)
    add_custom_target(StudioEventsGameDataValidate
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/validate-gamedata.py"
            "${STUDIOEVENTS_GAMEDATA_DIR}" --manifest "${CMAKE_CURRENT_SOURCE_DIR}/scripts/manifests/studioevents.json"
        COMMENT "Validating StudioEvents gamedata against the manifest"
        VERBATIM)
    add_dependencies(StudioEventsGameDataValidate StudioEventsGameData)
    add_dependencies(StudioEvents StudioEventsGameDataValidate)
endif()
install(DIRECTORY "${STUDIOEVENTS_GAMEDATA_DIR}/" DESTINATION svencoop/metahook/gamedata/studioevents OPTIONAL)
