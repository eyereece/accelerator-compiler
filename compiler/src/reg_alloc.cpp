#include "reg_alloc.h"
#include "validate.h"

#include <stdexcept>
#include <string>

namespace accel {

RegAlloc allocate_reg(const Program& program) {
    // Ensure all value IDs and operand references are valid first.
    validate(program);

    RegAlloc allocation;
    std::uint32_t next_reg = 0;

    for (const Operation& op : program.operations) {
        if (next_reg >= 8) {
            throw std::runtime_error(
                "Cannot assign a register to v" + std::to_string(op.result) +
                ": all 8 registers are assigned (register reuse is not implemented)");
        }

        // i.e., a result with ID 42 may be assigned register 0.
        // Value IDs do not have to equal register numbers.
        allocation.registers.emplace(op.result, next_reg);
        ++next_reg;
    }

    // Find the physical register holding the requested logical output.
    allocation.output_reg = allocation.registers.at(program.output);
    return allocation;
}

} // namespace accel
