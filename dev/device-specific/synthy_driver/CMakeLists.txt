add_library(synthy-driver-intf INTERFACE)
target_include_directories(
  synthy-driver-intf
  INTERFACE
  .
  device-config-intf
  micro-support-intf
)


add_library(synthy-driver OBJECT)
target_sources(
  synthy-driver
  PRIVATE
  synthy.c
)

target_link_libraries(
  synthy-driver
  PRIVATE
  device-config-intf
  micro-support-intf
)
