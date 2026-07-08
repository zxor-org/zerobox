cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "classic_spp_channel.cpp"
  "flutter_window.cpp"
  "main.cpp"
  "mi_account_2fa_channel.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "ws2_32.lib" "bthprops.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

set(WEBVIEW2_SDK_DIR "" CACHE PATH "Path to the Microsoft.Web.WebView2 NuGet package root")
if(NOT WEBVIEW2_SDK_DIR AND DEFINED ENV{WEBVIEW2_SDK_DIR})
  file(TO_CMAKE_PATH "$ENV{WEBVIEW2_SDK_DIR}" WEBVIEW2_SDK_DIR)
endif()

if(NOT WEBVIEW2_SDK_DIR AND DEFINED ENV{USERPROFILE})
  file(TO_CMAKE_PATH "$ENV{USERPROFILE}/.nuget/packages/microsoft.web.webview2" WEBVIEW2_NUGET_ROOT)
  file(GLOB WEBVIEW2_NUGET_PACKAGES LIST_DIRECTORIES true "${WEBVIEW2_NUGET_ROOT}/*")
  list(SORT WEBVIEW2_NUGET_PACKAGES)
  list(REVERSE WEBVIEW2_NUGET_PACKAGES)
  if(WEBVIEW2_NUGET_PACKAGES)
    list(GET WEBVIEW2_NUGET_PACKAGES 0 WEBVIEW2_SDK_DIR)
  endif()
endif()

if(NOT WEBVIEW2_SDK_DIR)
  file(GLOB WEBVIEW2_LOCAL_PACKAGES LIST_DIRECTORIES true
    "${CMAKE_SOURCE_DIR}/packages/Microsoft.Web.WebView2*"
    "${CMAKE_SOURCE_DIR}/packages/microsoft.web.webview2*"
  )
  list(SORT WEBVIEW2_LOCAL_PACKAGES)
  list(REVERSE WEBVIEW2_LOCAL_PACKAGES)
  if(WEBVIEW2_LOCAL_PACKAGES)
    list(GET WEBVIEW2_LOCAL_PACKAGES 0 WEBVIEW2_SDK_DIR)
  endif()
endif()

if(WEBVIEW2_SDK_DIR AND EXISTS "${WEBVIEW2_SDK_DIR}/build/native/include/WebView2.h")
  target_include_directories(${BINARY_NAME} PRIVATE "${WEBVIEW2_SDK_DIR}/build/native/include")
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(WEBVIEW2_ARCH "x64")
  else()
    set(WEBVIEW2_ARCH "x86")
  endif()
  set(WEBVIEW2_STATIC_LOADER "${WEBVIEW2_SDK_DIR}/build/native/${WEBVIEW2_ARCH}/WebView2LoaderStatic.lib")
  set(WEBVIEW2_IMPORT_LOADER "${WEBVIEW2_SDK_DIR}/build/native/${WEBVIEW2_ARCH}/WebView2Loader.dll.lib")
  set(WEBVIEW2_LOADER_DLL "${WEBVIEW2_SDK_DIR}/build/native/${WEBVIEW2_ARCH}/WebView2Loader.dll")
  if(EXISTS "${WEBVIEW2_STATIC_LOADER}")
    target_compile_definitions(${BINARY_NAME} PRIVATE "ZEROBOX_HAVE_WEBVIEW2")
    target_link_libraries(${BINARY_NAME} PRIVATE "${WEBVIEW2_STATIC_LOADER}" "ole32.lib")
  elseif(EXISTS "${WEBVIEW2_IMPORT_LOADER}")
    target_compile_definitions(${BINARY_NAME} PRIVATE "ZEROBOX_HAVE_WEBVIEW2")
    target_link_libraries(${BINARY_NAME} PRIVATE "${WEBVIEW2_IMPORT_LOADER}" "ole32.lib")
    if(EXISTS "${WEBVIEW2_LOADER_DLL}")
      add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${WEBVIEW2_LOADER_DLL}"
          "$<TARGET_FILE_DIR:${BINARY_NAME}>/WebView2Loader.dll")
    endif()
  else()
    message(WARNING "WebView2 SDK found, but no loader library was found for ${WEBVIEW2_ARCH}. Windows Xiaomi 2FA will be unavailable.")
  endif()
else()
  message(WARNING "Microsoft.Web.WebView2 SDK not found. Run windows\\scripts\\install_webview2_sdk.ps1 or set WEBVIEW2_SDK_DIR to enable Windows Xiaomi 2FA WebView.")
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
