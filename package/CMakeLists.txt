add_custom_target(sign
  COMMAND codesign --deep --force --options runtime --timestamp --verbose
          --entitlements "${PROJECT_SOURCE_DIR}/resources/Squirrel.entitlements"
          --sign "${SIGN_KEY}" "${BUNDLE_PATH}"
  DEPENDS Squirrel
)

add_custom_target(package
  COMMAND ./make_package
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  DEPENDS sign
)
