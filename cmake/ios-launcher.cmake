# GeneralsX @build Codex 19/11/2026 Isolated engine frameworks for the combined iOS launcher.
function(gx_add_ios_engine target standalone name)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
        return()
    endif()
    get_target_property(engine_sources ${standalone} SOURCES)
    get_target_property(engine_includes ${standalone} INCLUDE_DIRECTORIES)
    get_target_property(engine_libraries ${standalone} LINK_LIBRARIES)
    add_library(${target} SHARED ${engine_sources}
        "${CMAKE_SOURCE_DIR}/Core/GameEngine/Source/Common/System/GameMemory.cpp")
    # Compile the allocator translation unit with the collection policy. Its definitions
    # satisfy the static engine archive, so the standalone allocator object is not extracted.
    target_include_directories(${target} PRIVATE ${engine_includes}
        "${CMAKE_CURRENT_SOURCE_DIR}/../GameEngine/Include/Precompiled")
    target_link_libraries(${target} PRIVATE ${engine_libraries})
    target_compile_definitions(${target} PRIVATE SDL_MAIN_HANDLED=1 GX_COMBINED_ENGINE=1)
    # Only this C entry point is visible. Each engine owns its legacy globals;
    # the launcher dlopens just one framework with RTLD_LOCAL and never unloads it.
    target_link_options(${target} PRIVATE "-Wl,-exported_symbol,_GXEngineMain")
    set_target_properties(${target} PROPERTIES
        FRAMEWORK TRUE FRAMEWORK_VERSION A
        OUTPUT_NAME ${name}
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/ios-engines"
        MACOSX_FRAMEWORK_IDENTIFIER "com.generalsx.${name}"
        MACOSX_FRAMEWORK_BUNDLE_VERSION 1
        MACOSX_FRAMEWORK_SHORT_VERSION_STRING 1.0
        BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "@executable_path/Frameworks"
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO)
endfunction()
