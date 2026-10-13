#ifndef ACCEL_COMPILER_EXEC_H
#define ACCEL_COMPILER_EXEC_H

#include <array>
#include <cstdint>
#include <vector>

namespace accel {

// Execute instruction words and return all eight final register values.
// Models ISA behavior, not clock cycles or scalar handshakes.

std::array<std::uint32_t, 8> execute(
    const std::vector<std::uint32_t>& words);

}   // namespace accel

#endif