cmake_minimum_required(VERSION 3.22)
# Enable CMake support for ASM and C languages
enable_language(C ASM)
# STM32CubeMX generated symbols (macros)
set(MX_Defines_Syms
  USE_HAL_DRIVER
  STM32F411xE
  $<$<CONFIG:Debug>:DEBUG>
)

# STM32CubeMX generated include paths
set(MX_Include_Dirs
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Inc
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Inc/Legacy
  ${CMAKE_CURRENT_SOURCE_DIR}/CMSIS/Device/ST/STM32F4xx/Include
  ${CMAKE_CURRENT_SOURCE_DIR}/CMSIS/Include
)

# STM32 HAL/LL Drivers
set(STM32_Drivers_Src
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/system_stm32f4xx.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_cortex.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_dma_ex.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_dma.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_exti.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_flash_ex.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_flash_ramfunc.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_flash.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_gpio.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_pwr_ex.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_pwr.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_rcc_ex.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_rcc.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_tim.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_tim_ex.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_uart.c
  ${CMAKE_CURRENT_SOURCE_DIR}/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal.c
)


# Interface library for includes and symbols
add_library(micro-support-intf INTERFACE)
target_include_directories(
  micro-support-intf
  INTERFACE
  ${MX_Include_Dirs}
)
target_compile_definitions(
  micro-support-intf
  INTERFACE
  ${MX_Defines_Syms}
)

# Create STM32_Drivers static library
add_library(micro-support OBJECT)

target_sources(
  micro-support
  PRIVATE
  ${STM32_Drivers_Src}
)
target_link_libraries(
  micro-support
  PRIVATE
  device-config-intf
  micro-support-intf
)
