#include "enc.h"
#include "validate.h"

#include <stdexcept>
#include <string>

namespace accel {

std::vector<std::uint32_t> encode(const Program& program,
                                const RegAlloc& allocation) {
    validate(program);
    std::vector<std::uint32_t> words;

    // Look up a logical value's physical register and check it fits 3 bits.
    const auto reg_number = [&allocation](ValueId id) -> std::uint32_t {
        const auto it = allocation.registers.find(id);
        if (it == allocation.registers.end() || it->second >= 8) {
            throw std::runtime_error(
                "Missing or invalid register assignment for v" +
                std::to_string(id));
        }
        return it->second;
    };

    for (const Operation& op : program.operations) {
        const std::size_t needed = op.kind == OpKind::Constant ? 2 : 1;

        // Reserve one additional word for the final HALT.
        if (words.size() + needed + 1 > 512) {
            throw std::runtime_error("Encoded program exceeds 512 words");
        }

        const std::uint32_t rd = reg_number(op.result);

        if (op.kind == OpKind::Constant) {
            // LOAD_IMM: opcode 1 in [31:28], destination in [27:25].
            words.push_back((1u << 28) | (rd << 25));
            // The next word is the complete constant, with no bit shifting.
            words.push_back(op.immediate);
            continue;
        }

        // Map compiler operation kinds to the FPGA ISA explicitly.
        std::uint32_t opcode = 0;
        switch (op.kind) {
            case OpKind::Add: opcode = 2; break;
            case OpKind::Sub: opcode = 3; break;
            case OpKind::Mul: opcode = 4; break;
            default:
                throw std::runtime_error("Unsupported operation during encoding");
        }

        const std::uint32_t ra = reg_number(op.lhs);
        const std::uint32_t rb = reg_number(op.rhs);

        // Fields: opcode[31:28], rd[27:25], ra[24:22], rb[21:19].
        // No fields are placed in [18:0], so those bits remain zero.
        words.push_back((opcode << 28) | (rd << 25) |
                        (ra << 22) | (rb << 19));
    }

    words.push_back(0u); // HALT: opcode 0, all unused fields zero.
    return words;
}

} // namespace accel
