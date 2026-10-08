#ifndef ACCEL_COMPILER_ENC_H
#define ACCEL_COMPILER_ENC_H

#include "ir.h"
#include "reg_alloc.h"

#include <cstdint>
#include <vector>

namespace accel {

// Convert IR to FPGA instruction words.
std::vector<std::uint32_t> encode(const Program& program,
                                const RegAlloc& allocation);

} // namespace accel

#endif
