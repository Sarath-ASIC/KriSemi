#include <stdint.h>

/* AHB slave base address from the Libero subsystem memory map */
#define SLAVE_BASE_ADDR  (0x30000000UL)

void Reset_Handler(void)
{
    volatile uint32_t *ahb_slave =
        (volatile uint32_t *)SLAVE_BASE_ADDR;

    /* Write test data to the four implemented registers */
    ahb_slave[0] = 0x12345678;
    ahb_slave[1] = 0xA5A5A5A5;
    ahb_slave[2] = 0xCAFEBABE;
    ahb_slave[3] = 0xDEADBEEF;

    /* Stop here */
    while (1)
    {
        __asm volatile ("nop");
    }
}


/*
 * Cortex-M3 vector table
 *
 * Word 0: Initial Stack Pointer
 * Word 1: Reset Handler address
 */
__attribute__((section(".isr_vector")))
const uint32_t vector_table[] =
{
    0x20004000,
    (uint32_t)Reset_Handler
};
