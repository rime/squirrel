include(ExternalProject)

ExternalProject_Add(BuildRime
  SOURCE_DIR "${PROJECT_SOURCE_DIR}/librime"
  INSTALL_DIR "${PROJECT_BINARY_DIR}/librime"
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
             -DCMAKE_BUILD_TYPE=Release
             -DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}
             -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}
             -DBUILD_MERGED_PLUGINS=OFF
             -DENABLE_EXTERNAL_PLUGINS=ON
             -DBUILD_TEST=OFF
)

add_library(rime INTERFACE)
add_dependencies(rime BuildRime)
target_include_directories(rime INTERFACE "${PROJECT_BINARY_DIR}/librime/include")
target_link_directories(rime INTERFACE "${PROJECT_BINARY_DIR}/librime/lib/")
target_link_libraries(rime INTERFACE -lrime)

find_path(X11Keysym X11/keysym.h)
target_include_directories(rime INTERFACE ${X11Keysym})
