# Info.plist
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist" INFO_PLIST)
string(REPLACE "$(PRODUCT_BUNDLE_IDENTIFIER)" "@MACOSX_BUNDLE_GUI_IDENTIFIER@" INFO_PLIST "${INFO_PLIST}")
string(REPLACE "$(CURRENT_PROJECT_VERSION)" "@MACOSX_BUNDLE_BUNDLE_VERSION@" INFO_PLIST "${INFO_PLIST}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" "${INFO_PLIST}")
set_target_properties(Squirrel PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_BINARY_DIR}/Info.plist
)

# Static resources
set(FILES
  ${PROJECT_SOURCE_DIR}/README.md
  ${PROJECT_SOURCE_DIR}/LICENSE.txt
  rime.pdf
)
foreach(f ${FILES})
  get_filename_component(filename ${f} NAME)
  configure_file(${f} ${BUNDLE_RESOURCES_DIR}/${filename} COPYONLY)
endforeach()

# Localization
include(AppleUtils)
process_xcstrings(${CMAKE_CURRENT_SOURCE_DIR}/Localizable.xcstrings ${BUNDLE_RESOURCES_DIR})
process_xcstrings(${CMAKE_CURRENT_SOURCE_DIR}/InfoPlist.xcstrings ${BUNDLE_RESOURCES_DIR})

# RimeIcon.icns
add_custom_command(
  OUTPUT ${BUNDLE_RESOURCES_DIR}/RimeIcon.icns
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${PROJECT_SOURCE_DIR}/Assets.xcassets/RimeIcon.appiconset ${CMAKE_BINARY_DIR}/RimeIcon.iconset && iconutil -c icns ${CMAKE_BINARY_DIR}/RimeIcon.iconset -o ${BUNDLE_RESOURCES_DIR}/RimeIcon.icns
)
add_custom_target(RimeIcon.icns ALL DEPENDS ${BUNDLE_RESOURCES_DIR}/RimeIcon.icns)
