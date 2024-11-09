set(OUTDIR "${BUNDLE_SHARED_SUPPORT_DIR}")

# ##############################################################################
# Plum
# ##############################################################################
add_custom_command(
  OUTPUT "${OUTDIR}/default.yaml"
  COMMAND make "OUTPUT=${OUTDIR}" -C "${PROJECT_SOURCE_DIR}/plum"
  COMMENT "plum: update default schemas")
add_custom_target(plum-data ALL
  DEPENDS "${OUTDIR}/default.yaml")

# ##############################################################################
# OpenCC
# ##############################################################################
add_custom_command(
  OUTPUT "${OUTDIR}/opencc/s2t.json"
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${PROJECT_SOURCE_DIR}/librime/share/opencc ${OUTDIR}/opencc
  COMMENT "opencc: copy data")
add_custom_target(opencc-data ALL
  DEPENDS "${OUTDIR}/opencc/s2t.json")
