#ifndef ACCEL_COMPILER_IR_LOADER_H
#define ACCEL_COMPILER_IR_LOADER_H

#include "ir.h"
#include <string>

namespace accel {
// parse text ir file into existing Program structure
Program load_ir(const std::string& path);
}   // namespace accel

#endif  // ACCEL_COMPILER_IR_LOADER_H