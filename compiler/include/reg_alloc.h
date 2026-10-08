#ifndef ACCEL_COMPILER_REGISTER_ALLOC_H
#define ACCEL_COMPILER_REGISTER_ALLOC_H

#include "ir.h"

#include <cstdint>
#include <unordered_map>

namespace accel {

struct RegAlloc {
    // Key: logical value ID. Value: physical register number (0..7).
    std::unordered_map<ValueId, std::uint32_t> registers;
    std::uint32_t output_reg = 0;
};

// Validate the IR, then assign one fresh register to every operation result.
// Throws runtime_error for invalid IR or more than eight results.
// Does not modify the program or reuse registers.
RegAlloc allocate_reg(const Program& program);

} // namespace accel

#endif
