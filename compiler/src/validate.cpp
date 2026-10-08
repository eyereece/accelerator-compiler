#include "validate.h"

#include <stdexcept>
#include <string>
#include <unordered_set>

namespace accel {

void validate(const Program& program) {
    // Contains only values produced by earlier operations.
    std::unordered_set<ValueId> defined;

    for (const Operation& op : program.operations) {
        if (defined.count(op.result) != 0) {
            throw std::runtime_error(
                "Duplicate definition of v" + std::to_string(op.result));
        }

        switch (op.kind) {
            case OpKind::Constant:
                // Constants have no operands to check.
                break;

            case OpKind::Add:
            case OpKind::Sub:
            case OpKind::Mul:
                if (defined.count(op.lhs) == 0) {
                    throw std::runtime_error(
                        "v" + std::to_string(op.result) +
                        " uses undefined left operand v" +
                        std::to_string(op.lhs));
                }
                if (defined.count(op.rhs) == 0) {
                    throw std::runtime_error(
                        "v" + std::to_string(op.result) +
                        " uses undefined right operand v" +
                        std::to_string(op.rhs));
                }
                break;

            default:
                throw std::runtime_error(
                    "Unknown operation kind for v" +
                    std::to_string(op.result));
        }

        // Insert AFTER checking operands: a value cannot use itself
        // as an input to its own definition.
        defined.insert(op.result);
    }

    if (defined.count(program.output) == 0) {
        throw std::runtime_error(
            "Output v" + std::to_string(program.output) +
            " is not defined");
    }
}

} // namespace accel
