/* SOURCE FILE: main.c*/
#include "xil_printf.h"
#include "xil_io.h"
#include "xstatus.h"
#include "sleep.h"
#include <stdint.h>

/*
 * AXI Matrix Multiplication Accelerator
 * Target: Zynq-7000 / ARM Cortex-A9
 *
 * IMPORTANT:
 * Confirm that this base address belongs to the
 * custom accelerator in the hardware actually loaded.
 */

#define ACCEL_BASE       0x40000000U

#define REG_A0            0x00U
#define REG_A1            0x04U
#define REG_A2            0x08U
#define REG_A3            0x0CU

#define REG_B0            0x10U
#define REG_B1            0x14U
#define REG_B2            0x18U
#define REG_B3            0x1CU

#define REG_CONTROL       0x20U
#define REG_STATUS        0x24U

#define REG_C0            0x28U
#define REG_C1            0x2CU
#define REG_C2            0x30U
#define REG_C3            0x34U

#define CONTROL_START     0x01U
#define STATUS_DONE       0x01U
#define STATUS_BUSY       0x02U

#define POLL_LIMIT        10000000U

static void accel_write(uint32_t offset, uint32_t value)
{
    Xil_Out32(ACCEL_BASE + offset, value);
}

static uint32_t accel_read(uint32_t offset)
{
    return Xil_In32(ACCEL_BASE + offset);
}

int main(void)
{
    uint32_t status;
    uint32_t poll_count;

    int32_t c0, c1, c2, c3;

    xil_printf("\r\n");
    xil_printf("================================\r\n");
    xil_printf(" AXI Matrix Multiplication Test\r\n");
    xil_printf("================================\r\n");

    /*
     * A = [1 2]       B = [5 6]
     *     [3 4]           [7 8]
     *
     * Expected C = A x B:
     * C = [19 22]
     *     [43 50]
     */

    xil_printf("Writing matrix A...\r\n");

    accel_write(REG_A0, 1U);
    accel_write(REG_A1, 2U);
    accel_write(REG_A2, 3U);
    accel_write(REG_A3, 4U);

    xil_printf("Writing matrix B...\r\n");

    accel_write(REG_B0, 5U);
    accel_write(REG_B1, 6U);
    accel_write(REG_B2, 7U);
    accel_write(REG_B3, 8U);

    /* Start the accelerator. */
    xil_printf("Starting accelerator...\r\n");

    accel_write(REG_CONTROL, CONTROL_START);

    /*
     * Poll STATUS until DONE is asserted.
     * A finite limit prevents an infinite wait.
     */
    poll_count = 0U;

    do
    {
        status = accel_read(REG_STATUS);
        poll_count++;

        if ((status & STATUS_DONE) != 0U)
        {
            break;
        }

    } while (poll_count < POLL_LIMIT);

    if ((status & STATUS_DONE) == 0U)
    {
        xil_printf("ERROR: Accelerator timeout!\r\n");
        xil_printf("Last STATUS = 0x%08lx\r\n",
                   (unsigned long)status);

        while (1)
        {
            /* Stop here for debugging. */
        }
    }

    xil_printf("Accelerator completed.\r\n");

    /* Read the four 32-bit results. */
    c0 = (int32_t)accel_read(REG_C0);
    c1 = (int32_t)accel_read(REG_C1);
    c2 = (int32_t)accel_read(REG_C2);
    c3 = (int32_t)accel_read(REG_C3);

    xil_printf("\r\nResult matrix C:\r\n");

    xil_printf("[%ld  %ld]\r\n",
               (long)c0, (long)c1);

    xil_printf("[%ld  %ld]\r\n",
               (long)c2, (long)c3);

    /* Check against expected values. */
    if ((c0 == 19) && (c1 == 22) &&
        (c2 == 43) && (c3 == 50))
    {
        xil_printf("\r\nPASS: Matrix multiplication correct!\r\n");
    }
    else
    {
        xil_printf("\r\nFAIL: Unexpected result!\r\n");
    }

    while (1)
    {
        /* Keep application running for inspection. */
    }

    return 0;
}
