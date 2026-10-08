#ifndef ACCEL_COMPILER_IR_H
#define ACCEL_COMPILER_IR_H

#include <cstdint>
#include <vector>

namespace accel {

using ValueId = std::uint32_t;

// Compiler operation kids
enum class OpKind {
    Constant,
    Add,
    Sub,
    Mul
};

struct Operation {
    OpKind kind;
    ValueId result;     // logical value produced by this operation

    ValueId lhs = 0;
    ValueId rhs = 0;
    ValueId immediate = 0;
};

struct Program {
    std::vector<Operation> operations;
    ValueId output;
};

}   // namespace accel

#endif