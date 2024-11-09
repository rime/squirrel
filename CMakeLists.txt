cmake_minimum_required(VERSION 3.30)
project(squirrel VERSION 1.0.2 LANGUAGES CXX Swift)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# ##############################################################################
# Options
# ##############################################################################
set(DEV_ID "UNSET" CACHE STRING "Dev ID for code-signing")
set(SIGN_KEY "UNSET" CACHE STRING "Sign key for code-signing")
option(FIXUP_WHEN_BUILD "Fix-up the app bundle in build time" ON)

if(NOT (DEV_ID STREQUAL "UNSET") AND (SIGN_KEY STREQUAL "UNSET"))
  set(SIGN_KEY "Developer ID Application: ${DEV_ID}")
endif()

# ##############################################################################
# Dependencies
# ##############################################################################
include(AddSparkle)
include(AddRime)

# ##############################################################################
# Squirrel.app
# ##############################################################################
file(GLOB SRCS "${PROJECT_SOURCE_DIR}/Sources/*.swift")
add_executable(Squirrel MACOSX_BUNDLE ${SRCS})
target_compile_options(Squirrel PRIVATE
  -import-objc-header "${PROJECT_SOURCE_DIR}/Sources/Squirrel-Bridging-Header.h"
  -enable-bare-slash-regex
)
target_include_directories(Squirrel PRIVATE
  "${PROJECT_SOURCE_DIR}/Sources"
  "${PROJECT_SOURCE_DIR}/librime/src"
)
target_link_libraries(Squirrel PRIVATE rime Sparkle)

set(BUNDLE_PATH "${PROJECT_BINARY_DIR}/Squirrel.app")
set(BUNDLE_CONTENTS_DIR "${BUNDLE_PATH}/Contents")
set(BUNDLE_BIN_DIR "${BUNDLE_CONTENTS_DIR}/MacOS")
set(BUNDLE_RESOURCES_DIR "${BUNDLE_CONTENTS_DIR}/Resources")
set(BUNDLE_FRAMEWORKS_DIR "${BUNDLE_CONTENTS_DIR}/Frameworks")
set(BUNDLE_SHARED_SUPPORT_DIR "${BUNDLE_CONTENTS_DIR}/SharedSupport")

set_target_properties(Squirrel PROPERTIES
  MACOSX_BUNDLE_GUI_IDENTIFIER im.rime.inputmethod.Squirrel
  MACOSX_BUNDLE_BUNDLE_VERSION ${CMAKE_PROJECT_VERSION}
)

# Copy additional binaries
file(GLOB RIME_PROGRAMS "${CMAKE_BINARY_DIR}/librime/bin/rime_*")
add_custom_command(TARGET Squirrel POST_BUILD
  COMMAND cp -a "${CMAKE_BINARY_DIR}/librime/bin/rime_*" ${BUNDLE_BIN_DIR})

# Copy resources
add_subdirectory(resources)

# Copy built-in schemas
add_subdirectory(data)

# Copy linked frameworks and libraries
add_custom_command(TARGET Squirrel POST_BUILD
  COMMAND rsync -a "${CMAKE_CURRENT_BINARY_DIR}/librime/lib/" "${BUNDLE_FRAMEWORKS_DIR}"
          --exclude pkgconfig
)
add_custom_command(TARGET Squirrel POST_BUILD
  COMMAND rsync -a "${CMAKE_BINARY_DIR}/Sparkle.framework"
          "${BUNDLE_FRAMEWORKS_DIR}"
          --exclude=Headers --exclude=PrivateHeaders --exclude=Modules
)

# Fix linking so that the bundle is standalone
set(FIXUP_SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/fixup.cmake)
set(FIXUP_DIRS "${BUNDLE_FRAMEWORKS_DIR}")
file(WRITE ${FIXUP_SCRIPT} "
  include(BundleUtilities)
  file(GLOB PLUGINS ${BUNDLE_FRAMEWORKS_DIR}/rime-plugins/*.dylib)
  fixup_bundle(\"${BUNDLE_PATH}\" \"\${PLUGINS}\" \"${FIXUP_DIRS}\")
")
if(${FIXUP_WHEN_BUILD})
  add_custom_command(TARGET Squirrel POST_BUILD
    COMMAND ${CMAKE_COMMAND} -P ${FIXUP_SCRIPT}
  )
endif()

# Install (for development)
set(CMAKE_SKIP_RPATH TRUE)   # done by fixup_bundle
install(SCRIPT ${FIXUP_SCRIPT})
install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target sign)")
install(TARGETS Squirrel BUNDLE DESTINATION "/Library/Input\ Methods")

# ##############################################################################
# Distribution
# ##############################################################################
add_subdirectory(package)
