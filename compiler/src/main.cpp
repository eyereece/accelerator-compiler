#include "ir.h"
#include "validate.h"
#include "reg_alloc.h"

#include <iostream>
#include <stdexcept>

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

    } catch (const std::runtime_error& error) {
        std::cerr << "Register allocation failed: "
                << error.what() << '\n';
        return 1;
    }
    return 0;
}