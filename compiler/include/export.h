#ifndef ACCEL_COMPILER_EXPORT_H
#define ACCEL_COMPILER_EXPORT_H

#include <cstdint>
#include <string>
#include <vector>

namespace accel {

// write program.txt, program.h, and program.bin
// parent dir must already exist
void export_program(const std::vector<std::uint32_t>& words,
                    std::uint32_t output_reg,
                    const std::string& prefix);
}   // namespace accel

#endif