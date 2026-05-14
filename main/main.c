#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

void app_main(void)
{
    printf("Hello from ESP32-S3!\n");
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
