
#include "xil_printf.h"

int main(void)
{
    xil_printf("\r\nZC702 Bare-Metal Application Started!\r\n");
    xil_printf("ARM Cortex-A9 is running.\r\n");

    while (1)
    {
        /* Keep the application running */
    }

    return 0;
}
