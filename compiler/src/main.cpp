#include "ir.h"
#include "validate.h"
#include "reg_alloc.h"
#include "enc.h"

#include <iostream>
#include <stdexcept>
#include <iomanip>

int main() {
    using namespace accel;

    Program program{
        {
            // Kind, Result, lhs, rhs, immediate
            {OpKind::Constant, 0, 0, 0, 7},
            {OpKind::Constant, 1, 0, 0, 3},
            {OpKind::Add,      2, 0, 1},
            {OpKind::Constant, 3, 0, 0, 2},
            {OpKind::Mul,      4, 2, 3}
        },
        4 // Output value ID
    };

    // Validate before continuing with the program.
    try {
        validate(program);
        std::cout << "IR validation passed\n";
    } catch (const std::runtime_error& error) {
        std::cerr << "IR validation failed: " << error.what() << '\n';
        return 1;
    }

    // Print the representation to see what was constructed.
    for (const Operation& op : program.operations) {
        std::cout << "v" << op.result << " = ";

        switch (op.kind) {
            case OpKind::Constant:
                std::cout << "constant " << op.immediate;
                break;

            case OpKind::Add:
            case OpKind::Sub:
            case OpKind::Mul: {
                const char* name =
                    op.kind == OpKind::Add ? "add" :
                    op.kind == OpKind::Sub ? "sub" : "mul";

                std::cout << name
                          << " v" << op.lhs
                          << ", v" << op.rhs;
                break;
            }
        }

        std::cout << '\n';
    }

    std::cout << "output: v" << program.output << '\n';

    try {
        const RegAlloc allocation = allocate_reg(program);

        std::cout << "\nRegister assignments:\n";

        for (const Operation& op : program.operations) {
            std::cout << "v" << op.result
                    << " -> R" << allocation.registers.at(op.result)
                    << '\n';
        }

        std::cout << "Output register: R"
                << allocation.output_reg << '\n';

        // Convert the IR and register assignments into FPGA words.
        const auto words = encode(program, allocation);

        std::cout << "\nEncoded program:\n";

        for (std::size_t i = 0; i < words.size(); ++i) {
            std::cout << std::dec << i << ": 0x"
                    << std::hex << std::uppercase
                    << std::setw(8) << std::setfill('0')
                    << words[i] << '\n';
        }

        // Restore decimal formatting for subsequent output.
        std::cout << std::dec << std::setfill(' ')
                << "Program words: " << words.size() << '\n';

    } catch (const std::runtime_error& error) {
        std::cerr << "Compilation failed: " << error.what() << '\n';
        return 1;
    }
    return 0;
}