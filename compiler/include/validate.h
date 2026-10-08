#ifndef ACCEL_COMPILER_VALIDATE_H
#define ACCEL_COMPILER_VALIDATE_H

#include "ir.h"

namespace accel {

// Return normally if valid; throw std::runtime_error on the first error.
void validate(const Program& program);

} // namespace accel

#endif
