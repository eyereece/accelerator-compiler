#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"

int main(void)
{
    uint32_t data = 0x12345678;

    // Write to custom avalon-mm register
    IOWR_32DIRECT(AVALON_TEST_REG_0_BASE, 0, data);

    // read back from same register
    uint32_t read_data = IORD_32DIRECT(AVALON_TEST_REG_0_BASE, 0);

    if (read_data == data) {
        puts("PASS");
    } else {
        puts("FAIL");
    }

    return 0;
}
