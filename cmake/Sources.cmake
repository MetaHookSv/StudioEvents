# Explicit compile list from StudioEvents.vcxproj. The SDK's interface.cpp
# implements EXPOSE_SINGLE_INTERFACE and exports CreateInterface.
set(STUDIOEVENTS_SOURCES
    "${PROJECT_SOURCE_DIR}/src/exportfuncs.cpp"
    "${PROJECT_SOURCE_DIR}/src/MurmurHash2.cpp"
    "${PROJECT_SOURCE_DIR}/src/plugins.cpp"
    "${PROJECT_SOURCE_DIR}/src/privatehook.cpp"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/common/interface.cpp"
)
