#include "exec.h"

#include <cstddef>
#include <stdexcept>
#include <string>

namespace accel {

std::array<std::uint32_t, 8> execute(const std::vector<std::uint32_t>& words) {
        if (words.empty() || words.size() > 512) {
            throw std::runtime_error("Program must contain 1 - 512 words");
        }

        // Every execution starts with cleared registers, including R8
        std::array<std::uint32_t, 8> registers{};
        std::size_t pc = 0;

        while (pc < words.size()) {
            const std::uint32_t instruction = words[pc];
            const std::uint32_t opcode = instruction >> 28;
            const std::uint32_t rd = (instruction >> 25) & 7u;
            const std::uint32_t ra = (instruction >> 22) & 7u;
            const std::uint32_t rb = (instruction >> 19) & 7u;

            switch (opcode) {
                case 0: // HALT: ignore remaining words, as hardware does
                    return registers;

                case 1: // LOAD_IMM: the next word is data, not an instruction
                    if (pc + 1 >= words.size()) {
                        throw std::runtime_error(
                            "Missing LOAD_IMM data at word" + std::to_string(pc));
                    }
                    registers[rd] = words[pc + 1];
                    pc += 2;
                    break;

                case 2: // ADD
                    registers[rd] = static_cast<std::uint32_t>(static_cast<std::uint64_t>(registers[ra]) + registers[rb]);
                    ++pc;
                    break;

                case 3: // SUB
                    registers[rd] = static_cast<std::uint32_t>(static_cast<std::uint64_t>(registers[ra]) - registers[rb]);
                    ++pc;
                    break;

                case 4: // MUL
                    registers[rd] = static_cast<std::uint32_t>(static_cast<std::uint64_t>(registers[ra]) * registers[rb]);
                    ++pc;
                    break;

                default:
                    throw std::runtime_error("Invalid opcode at word " + std::to_string(pc));
            }
        }

        throw std::runtime_error("Program reached the end without HALT");
    }
}   // namespace accel