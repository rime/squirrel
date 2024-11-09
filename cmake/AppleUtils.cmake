macro(process_xcstrings path outdir)
  get_filename_component(basename ${path} NAME_WLE)
  set(target ${outdir}/en.lproj/${basename}.strings)
  add_custom_command(
    OUTPUT ${target}
    COMMAND xcrun xcstringstool compile ${path} --output-directory ${outdir}
    COMMENT "Process ${basename}.xcstrings"
  )
  add_custom_target(xcstrings_${basename} ALL DEPENDS ${target})
endmacro()
