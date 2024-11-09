include(ExternalProject)

ExternalProject_Add(BuildSparkle
  SOURCE_DIR "${PROJECT_SOURCE_DIR}/Sparkle"

  CONFIGURE_COMMAND ""

  BUILD_COMMAND xcodebuild -project "<SOURCE_DIR>/Sparkle.xcodeproj" -scheme Sparkle -configuration Release
  BUILD_IN_SOURCE TRUE

  # Install Sparkle.framework
  INSTALL_COMMAND cp -a "<SOURCE_DIR>/build/Release/Sparkle.framework" "${CMAKE_BINARY_DIR}"
)

add_library(Sparkle INTERFACE)
add_dependencies(Sparkle BuildSparkle)
target_include_directories(Sparkle INTERFACE "${CMAKE_BINARY_DIR}/Sparkle.framework/Headers")
target_link_libraries(Sparkle INTERFACE "${CMAKE_BINARY_DIR}/Sparkle.framework")
