/* USER CODE BEGIN Header */
/**
 ******************************************************************************
 * @file           : main.h
 * @brief          : Header for main.c file.
 *                   This file contains the common defines of the application.
 ******************************************************************************
 * @attention
 *
 * Copyright (c) 2025 2025 YUMENEGI INDUSTRIES.
 * All rights reserved.
 *
 * This software is licensed under terms that can be found in the LICENSE file
 * in the root directory of this software component.
 * If no LICENSE file comes with this software, it is provided AS-IS.
 *
 ******************************************************************************
 */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f4xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void HAL_TIM_MspPostInit(TIM_HandleTypeDef *htim);
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define B1_Pin GPIO_PIN_13
#define B1_GPIO_Port GPIOC
#define USART_TX_Pin GPIO_PIN_2
#define USART_TX_GPIO_Port GPIOA
#define USART_RX_Pin GPIO_PIN_3
#define USART_RX_GPIO_Port GPIOA
#define LD2_Pin GPIO_PIN_5
#define LD2_GPIO_Port GPIOA
#define TMS_Pin GPIO_PIN_13
#define TMS_GPIO_Port GPIOA
#define TCK_Pin GPIO_PIN_14
#define TCK_GPIO_Port GPIOA
#define SWO_Pin GPIO_PIN_3
#define SWO_GPIO_Port GPIOB

#define SN_D0_PIN GPIO_PIN_10
#define SN_D1_PIN GPIO_PIN_3
#define SN_D2_PIN GPIO_PIN_5
#define SN_D3_PIN GPIO_PIN_4
#define SN_D4_PIN GPIO_PIN_10
#define SN_D5_PIN GPIO_PIN_8
#define SN_D6_PIN GPIO_PIN_9
#define SN_D7_PIN GPIO_PIN_7
#define SN_WE_PIN GPIO_PIN_6

#define SN_D0_GPIO_PORT GPIOA
#define SN_D1_GPIO_PORT GPIOB
#define SN_D2_GPIO_PORT GPIOB
#define SN_D3_GPIO_PORT GPIOB
#define SN_D4_GPIO_PORT GPIOB
#define SN_D5_GPIO_PORT GPIOA
#define SN_D6_GPIO_PORT GPIOA
#define SN_D7_GPIO_PORT GPIOC
#define SN_WE_GPIO_PORT GPIOB

#define SIXTEENTH_DELAY_MS_95BPM 188
#define EIGHTH_DELAY_MS_95BPM 375
#define QUARTER_DELAY_MS_95BPM 750
#define HALF_DELAY_MS_95BPM 1500
#define WHOLE_DELAY_MS_95BPM 3000

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
