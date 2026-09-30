#include <stdio.h>
#include <stdint.h>
#include "system.h"
#include "io.h"

int main(void)
{
	// TEST: 7 + 3 = 10
	IOWR_32DIRECT(SCALAR_UNIT_0_BASE, 0x00, 123);	// a_in
	IOWR_32DIRECT(SCALAR_UNIT_0_BASE, 0x04, 84);	// b_in
	IOWR_32DIRECT(SCALAR_UNIT_0_BASE, 0x08, 0);
	IOWR_32DIRECT(SCALAR_UNIT_0_BASE, 0x0C, 1);	// valid signal: 1

	// wait until result_available == 1
	while ((IORD_32DIRECT(SCALAR_UNIT_0_BASE, 0x14) & 1) == 0) {
		// wait for scalar unit
	}

	// read result
	uint32_t result = IORD_32DIRECT(SCALAR_UNIT_0_BASE, 0x10);
	printf("123 + 84 = %lu\n", (unsigned long)result);

	// send result_ack
	IOWR_32DIRECT(SCALAR_UNIT_0_BASE, 0x18, 1);

	// verify result_available was cleared
	uint32_t available = IORD_32DIRECT(SCALAR_UNIT_0_BASE, 0x14);
	if ((available & 1) == 0) {
		puts("result acknowledged");
	} else {
		puts("result_available did not clear\n");
	}
    return 0;
}
