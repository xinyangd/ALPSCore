#
# Provide common definitions for building alps modules 
#

# Disable in-source builds
if (${CMAKE_BINARY_DIR} STREQUAL ${CMAKE_SOURCE_DIR})
    message(FATAL_ERROR "In source builds are disabled. Please use a separate build directory")
endif()

set(CMAKE_DISABLE_SOURCE_CHANGES ON)
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)

# RPATH fix
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
 set(CMAKE_INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/lib")
else()
 set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
endif()

#policy update CMP0042
if(APPLE)
  set(CMAKE_MACOSX_RPATH ON)
endif()

#Do Release-with-debug build by default
#If it is not set, remove it from the cache
if (NOT CMAKE_BUILD_TYPE)
  unset(CMAKE_BUILD_TYPE CACHE)
endif()
set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Build type, such as `Debug` or `Release`")
mark_as_advanced(CMAKE_BUILD_TYPE)

# This option is checked, e.g., when adding -DBOOST_DISABLE_ASSERTS.
option(ALPS_DEBUG "Set to TRUE to supress auto-adjusting your compilation flags" false)
mark_as_advanced(ALPS_DEBUG)

# GF uses boost::multi_array, to supress extra checks we need to define extra flags,
# otherwise codes will slow down to a crawl.
if (NOT ALPS_DEBUG)
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -DBOOST_DISABLE_ASSERTS")
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO} -DBOOST_DISABLE_ASSERTS")
endif()

# Build static XOR shared 
# Defines ALPS_BUILD_TYPE=STATIC|DYNAMIC .
set(ALPS_BUILD_TYPE "dynamic" CACHE STRING "Build type: `static`, `dynamic` or `unspecified`")
set_property(CACHE ALPS_BUILD_TYPE PROPERTY STRINGS static dynamic unspecified)
string(TOLOWER ${ALPS_BUILD_TYPE}  ALPS_BUILD_TYPE)

# We do not want those variables in cache:
unset(ALPS_BUILD_SHARED)
unset(ALPS_BUILD_STATIC)
if (DEFINED ALPS_BUILD_STATIC OR DEFINED ALPS_BUILD_SHARED)
  message(WARNING "Setting ALPS_BUILD_SHARED, ALPS_BUILD_STATIC in cache does not have any effect.")
endif()
unset(ALPS_BUILD_SHARED CACHE)
unset(ALPS_BUILD_STATIC CACHE)

if (ALPS_BUILD_TYPE STREQUAL dynamic)
  set(ALPS_BUILD_SHARED true)
  set(ALPS_BUILD_STATIC false)
  message(STATUS "Building shared libraries")
  unset(BUILD_SHARED_LIBS CACHE)
  option(BUILD_SHARED_LIBS "Generate shared libraries" ON)
elseif (ALPS_BUILD_TYPE STREQUAL static)
  set(ALPS_BUILD_SHARED false)
  set(ALPS_BUILD_STATIC true)
  message(STATUS "Doing static build")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")
  unset(BUILD_SHARED_LIBS CACHE)
  option(BUILD_SHARED_LIBS "Generate shared libraries" OFF)
elseif (ALPS_BUILD_TYPE STREQUAL unspecified)
  # Special case: just go after BUILD_SHARED_LIBS, everything else is default.
  set(ALPS_BUILD_SHARED false)
  set(ALPS_BUILD_STATIC false)
  option(BUILD_SHARED_LIBS "Generate shared libraries" ON) # << user will likely override it
  message(WARNING "NOTE: Will generate libraries depending on BUILD_SHARED_LIBS option, which is set to ${BUILD_SHARED_LIBS}")
  message(WARNING "Be sure you know what you are doing!")
else()
  message(FATAL_ERROR "ALPS_BUILD_TYPE should be set to either 'static' or 'dynamic' (or 'unspecified' only if you know what your are doing)")
endif()
option(ALPS_BUILD_PIC "Generate position-independent code (PIC)" OFF)

# Set ALPS_ROOT as a hint for standalone component builds
if (DEFINED ENV{ALPS_ROOT})
  set(ALPS_ROOT "$ENV{ALPS_ROOT}" CACHE PATH "Path to ALPSCore installation (for standalone component builds)")
  mark_as_advanced(ALPS_ROOT)
endif()


## Some macros

# add includes and libs for each module
macro(alps_add_module module module_path)
    set(${module}_INCLUDE_DIRS ${CMAKE_SOURCE_DIR}/${module_path}/include ${CMAKE_BINARY_DIR}/${module_path}/include)
    set(${module}_LIBRARIES ${module})
endmacro(alps_add_module)

macro(add_boost) # usage: add_boost(component1 component2...)
  if (ALPS_BUILD_STATIC)
    set(Boost_USE_STATIC_LIBS        ON)
    #set(Boost_USE_STATIC_RUNTIME    OFF)
  endif()
  if (ALPS_BUILD_SHARED)
    set(Boost_USE_STATIC_LIBS        OFF)
  endif()
  find_package (Boost 1.54.0 COMPONENTS ${ARGV} REQUIRED)
  message(STATUS "Boost includes: ${Boost_INCLUDE_DIRS}" )
  message(STATUS "Boost libs: ${Boost_LIBRARIES}" )
  target_include_directories(${PROJECT_NAME} SYSTEM PUBLIC ${Boost_INCLUDE_DIRS})
  target_link_libraries(${PROJECT_NAME} PUBLIC ${Boost_LIBRARIES})
endmacro(add_boost)

macro(add_hdf5) 
  if (ALPS_BUILD_STATIC)
    set(HDF5_USE_STATIC_LIBRARIES ON)
  endif()
  if (ALPS_BUILD_SHARED)
    set(HDF5_USE_STATIC_LIBRARIES OFF)
  endif()
  find_package (HDF5 REQUIRED)
  message(STATUS "HDF5 includes: ${HDF5_INCLUDE_DIRS}" )
  message(STATUS "HDF5 libs: ${HDF5_LIBRARIES}" )
  target_include_directories(${PROJECT_NAME} SYSTEM PUBLIC ${HDF5_INCLUDE_DIRS})
  target_link_libraries(${PROJECT_NAME} PUBLIC ${HDF5_LIBRARIES})
endmacro(add_hdf5)

# Usage: add_alps_package(pkgname1 pkgname2...)
# Sets variable ${PROJECT_NAME}_DEPENDS
macro(add_alps_package)
    list(APPEND ${PROJECT_NAME}_DEPENDS ${ARGV})
    foreach(pkg_ ${ARGV})
        if (DEFINED ALPS_GLOBAL_BUILD)
            include_directories(BEFORE ${${pkg_}_INCLUDE_DIRS}) # this is needed to compile tests (FIXME: why?)
            message(STATUS "${pkg_} includes: ${${pkg_}_INCLUDE_DIRS}" )
        else(DEFINED ALPS_GLOBAL_BUILD)
            string(REGEX REPLACE "^alps-" "" pkgcomp_ ${pkg_})
            find_package(ALPSCore QUIET COMPONENTS ${pkgcomp_} HINTS ${ALPS_ROOT})
            if (ALPSCore_${pkgcomp_}_FOUND) 
              # message(STATUS "DEBUG: found as an ALPSCore component")
              set(${pkg_}_LIBRARIES ${ALPSCore_${pkgcomp_}_LIBRARIES})
            else()
              # message(STATUS "DEBUG: could not find ALPSCore, searching for the component directly")
              find_package(${pkg_} REQUIRED HINTS ${ALPS_ROOT})
            endif()
            # Imported targets returned by find_package() contain info about include dirs, no need to assign them
        endif (DEFINED ALPS_GLOBAL_BUILD)
        target_link_libraries(${PROJECT_NAME} PUBLIC ${${pkg_}_LIBRARIES})
        message(STATUS "${pkg_} libs: ${${pkg_}_LIBRARIES}")
    endforeach(pkg_)
endmacro(add_alps_package) 

# Usage: add_this_package(srcs...)
# The `srcs` are source file names in directory "src/"
# Defines ${PROJECT_NAME} target
# Exports alps::${PROJECT_NAME} target
function(add_this_package)
   # This is needed to compile tests:
   include_directories(
     ${PROJECT_SOURCE_DIR}/include
     ${PROJECT_BINARY_DIR}/include
   )
  
  set(src_list_ "")
  foreach(src_ ${ARGV})
    list(APPEND src_list_ "src/${src_}.cpp")
  endforeach()
  add_library(${PROJECT_NAME} ${src_list_})
  if (ALPS_BUILD_PIC) 
    set_target_properties(${PROJECT_NAME} PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()

  install(TARGETS ${PROJECT_NAME} 
          EXPORT ${PROJECT_NAME} 
          LIBRARY DESTINATION lib
          ARCHIVE DESTINATION lib
          INCLUDES DESTINATION include)
  install(EXPORT ${PROJECT_NAME} NAMESPACE alps:: DESTINATION share/${PROJECT_NAME})
  target_include_directories(${PROJECT_NAME} PRIVATE ${PROJECT_SOURCE_DIR}/include ${PROJECT_BINARY_DIR}/include)

  install(DIRECTORY include DESTINATION .
          FILES_MATCHING PATTERN "*.hpp" PATTERN "*.hxx"
         )
endfunction(add_this_package)

macro(add_testing)
  option(Testing "Enable testing" ON)
  if (Testing)
    enable_testing()
    add_subdirectory(test)
  endif (Testing)
endmacro(add_testing)

macro(gen_documentation)
  set(DOXYFILE_EXTRA_SOURCES "${DOXYFILE_EXTRA_SOURCES} ${PROJECT_SOURCE_DIR}/include ${PROJECT_SOURCE_DIR}/src" PARENT_SCOPE)
  option(Documentation "Build documentation" OFF)
  if (Documentation)
    set(DOXYFILE_SOURCE_DIR "${PROJECT_SOURCE_DIR}/include")
    set(DOXYFILE_IN "${PROJECT_SOURCE_DIR}/../common/doc/Doxyfile.in") 
    include(UseDoxygen)
  endif(Documentation)
endmacro(gen_documentation)

macro(gen_hpp_config)
  configure_file("${PROJECT_SOURCE_DIR}/include/config.hpp.in" "${PROJECT_BINARY_DIR}/include/alps/config.hpp")
  install(FILES "${PROJECT_BINARY_DIR}/include/alps/config.hpp" DESTINATION include/alps) 
endmacro(gen_hpp_config)

macro(gen_pkg_config)
  # Generate pkg-config file
  configure_file("${PROJECT_SOURCE_DIR}/${PROJECT_NAME}.pc.in" "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc")
  install(FILES "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc" DESTINATION "lib/pkgconfig")
endmacro(gen_pkg_config)


# Function: generates package-specific CMake configs
# Arguments: [DEPENDS <list-of-dependencies>] [EXPORTS <list-of-exported-targets>]
# If no <list-of-dependencies> are present, the contents of ${PROJECT_NAME}_DEPENDS is used
# If no exported targets are present, alps::${PROJECT_NAME} is assumed.
function(gen_cfg_module)
    include(CMakeParseArguments) # arg parsing helper
    cmake_parse_arguments(gen_cfg_module "" "" "DEPENDS;EXPORTS" ${ARGV})
    if (gen_cfg_module_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Incorrect call of gen_cfg_module([DEPENDS ...] [EXPORTS ...]): ARGV=${ARGV}")
    endif()
    if (gen_cfg_module_DEPENDS)
        set(DEPENDS ${gen_cfg_module_DEPENDS})
    else()
        set(DEPENDS ${${PROJECT_NAME}_DEPENDS})
    endif()
    if (gen_cfg_module_EXPORTS)
        set(EXPORTS ${gen_cfg_module_EXPORTS})
    else()
        set(EXPORTS alps::${PROJECT_NAME})
    endif()
    configure_file("${PROJECT_SOURCE_DIR}/../common/cmake/ALPSModuleConfig.cmake.in" 
                   "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" @ONLY)
    configure_file("${PROJECT_SOURCE_DIR}/../common/cmake/ALPSCoreConfig.cmake.in" 
                   "${PROJECT_BINARY_DIR}/ALPSCoreConfig.cmake" @ONLY)
    install(FILES "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" DESTINATION "share/${PROJECT_NAME}/")
    install(FILES "${PROJECT_BINARY_DIR}/ALPSCoreConfig.cmake" DESTINATION "share/ALPSCore/")
endfunction()

# # Requred parameters:
# #  project_search_file_ : filename helping to identify the location of the project 
# # Optional parameters:
# #  HEADER_ONLY : the package does not contain libraries
# #
# function(gen_find_module project_search_file_)
#   set(PROJECT_SEARCH_FILE ${project_search_file_})
#   set (NOT_HEADER_ONLY true)
#   foreach(arg ${ARGV})
#     if (arg STREQUAL "HEADER_ONLY")
#       set(NOT_HEADER_ONLY false)
#     endif()
#   endforeach()
#   configure_file("${PROJECT_SOURCE_DIR}/../common/cmake/ALPSModuleConfig.cmake.in" "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" @ONLY)
#   # configure_file("${PROJECT_SOURCE_DIR}/../common/cmake/FindALPSModule.cmake.in" "${PROJECT_BINARY_DIR}/Find${PROJECT_NAME}.cmake" @ONLY)
#   # install(FILES "${PROJECT_BINARY_DIR}/Find${PROJECT_NAME}.cmake" DESTINATION "share/cmake/Modules/")
#   install(FILES "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake" DESTINATION "share/${PROJECT_NAME}/")
#   install(FILES "${PROJECT_SOURCE_DIR}/../common/cmake/ALPSCoreConfig.cmake" DESTINATION "share/ALPSCore/")
#   install(FILES "${PROJECT_SOURCE_DIR}/../common/cmake/FindALPSCore.cmake" DESTINATION "share/cmake/Modules/")
# endfunction(gen_find_module)
