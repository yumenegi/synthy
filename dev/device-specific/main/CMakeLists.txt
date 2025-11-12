target_sources(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
  main.c
  startup_stm32f411xe.s
  stm32f4xx_hal_msp.c
  stm32f4xx_it.c
  syscalls.c
  sysmem.c
)

target_include_directories(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
  .
)

target_link_libraries(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
  device-config-intf
  micro-support
  micro-support-intf
  synthy-driver-intf
)

set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES ADDITIONAL_CLEAN_FILES ${CMAKE_PROJECT_NAME}.map)
