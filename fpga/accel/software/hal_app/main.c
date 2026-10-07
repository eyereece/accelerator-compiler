/* First board test: load accelerator instructions, launch, check R4 == 20.
 * All offsets below are BYTES (the _32DIRECT macros do not multiply by 4).
 */
#include <stdint.h>
#include <stdio.h>
#include "system.h"
#include "io.h"

#define REG_START          0x000u
#define REG_STATUS         0x004u
#define REG_PROGRAM_WORDS  0x008u
#define REG_R4             0x030u
#define PROGRAM_RAM        0x800u
#define STATUS_BUSY        0x1u
#define STATUS_DONE        0x2u
#define STATUS_ERROR       0x4u
#define MAX_POLLS          1000000u /* Read-count bound, not a timed delay. */

#if CONTROLLER_0_SPAN != 4096
#error "Controller address span must match the 4096-byte RTL interface."
#endif

static const uint32_t program[] = {
    0x10000000u, /* LOAD_IMM R0 */
    0x00000007u, /* constant 7 */
    0x12000000u, /* LOAD_IMM R1 */
    0x00000003u, /* constant 3 */
    0x24080000u, /* ADD R2, R0, R1 */
    0x16000000u, /* LOAD_IMM R3 */
    0x00000002u, /* constant 2 */
    0x48980000u, /* MUL R4, R2, R3 */
    0x00000000u  /* HALT */
};

int main(void)
{
    const uint32_t words = (uint32_t)(sizeof(program) / sizeof(program[0]));
    uint32_t status, result, i;

    printf("Controller test: (7 + 3) * 2\n");
    status = IORD_32DIRECT(CONTROLLER_0_BASE, REG_STATUS);
    if (status & STATUS_BUSY) {
        printf("FAIL: controller already busy; reset before retrying.\n");
        return 1;
    }

    /* Write each complete word through the controller's RAM loading window. */
    for (i = 0; i < words; ++i)
        IOWR_32DIRECT(CONTROLLER_0_BASE, PROGRAM_RAM + 4u * i, program[i]);

    IOWR_32DIRECT(CONTROLLER_0_BASE, REG_PROGRAM_WORDS, words);
    if (IORD_32DIRECT(CONTROLLER_0_BASE, REG_PROGRAM_WORDS) != words) {
        printf("FAIL: program-length readback mismatch.\n");
        return 1;
    }
    printf("Loaded %lu program words.\n", (unsigned long)words);

    /* START clears previous DONE/ERROR flags and the accelerator registers. */
    IOWR_32DIRECT(CONTROLLER_0_BASE, REG_START, 1u);

    /* Completion can occur before first read; seeing BUSY is not required. */
    for (i = 0; i < MAX_POLLS; ++i) {
        status = IORD_32DIRECT(CONTROLLER_0_BASE, REG_STATUS);
        if (status & STATUS_ERROR) {
            printf("FAIL: controller ERROR, status=0x%08lx\n", (unsigned long)status);
            return 1;
        }
        if (!(status & STATUS_BUSY) && (status & STATUS_DONE))
            break;
    }
    if (i == MAX_POLLS) {
        printf("FAIL: polling limit reached, status=0x%08lx\n", (unsigned long)status);
        return 1;
    }

    result = IORD_32DIRECT(CONTROLLER_0_BASE, REG_R4);
    printf("STATUS=0x%08lx\n", (unsigned long)status);
    printf("R4=%lu\n", (unsigned long)result);
    if (result != 20u) {
        printf("FAIL: expected R4=20.\n");
        return 1;
    }
    printf("PASS: (7 + 3) * 2 = 20\n");
    return 0;
}
