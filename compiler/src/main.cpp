
#include "ir.h"
#include "ir_loader.h"
#include "validate.h"
#include "reg_alloc.h"
#include "enc.h"
#include "exec.h"
#include "export.h"

#include <iostream>
#include <stdexcept>
#include <iomanip>
#include <filesystem>
#include <string>

int main(int argc, char* argv[]) {
    using namespace accel;

    if (argc < 2 || argc > 3) {
        std::cerr
            << "Usage: <compiled executable> <path to ir> [opt: output prefix]\n"
            << "Example: compiler\\phase0.exe compiler\\examples\\arithmetic.ir "
               "compiler/generated/program\n";
        return 1;
    }

    const std::string input_path = argv[1];

    const std::string output_prefix =
        argc == 3
            ? argv[2]
            : "compiler/generated/program";

    try {
        // 1. Read textual IR into a Program object
        Program program = load_ir(input_path);

        // 2. Validate IR
        validate(program);
        std::cout << "IR validation passed\n";

        // 3. Print loaded IR
        for (const Operation& op : program.operations) {
            std::cout << "v" << op.result << " = ";

            switch (op.kind) {
                case OpKind::Constant:
                    std::cout << "constant "
                              << op.immediate;
                    break;

                case OpKind::Add:
                case OpKind::Sub:
                case OpKind::Mul: {
                    const char* name =
                        op.kind == OpKind::Add ? "add" :
                        op.kind == OpKind::Sub ? "sub" :
                                                 "mul";

                    std::cout << name
                              << " v" << op.lhs
                              << ", v" << op.rhs;
                    break;
                }
            }

            std::cout << '\n';
        }

        std::cout << "output: v"
                  << program.output << '\n';

        // 4. Register allocation
        const RegAlloc allocation = allocate_reg(program);

        std::cout << "\nRegister assignments:\n";

        for (const Operation& op : program.operations) {
            std::cout
                << "v" << op.result
                << " -> R"
                << allocation.registers.at(op.result)
                << '\n';
        }

        std::cout << "Output register: R"
                  << allocation.output_reg << '\n';

        // 5. Encode instructions
        const auto words = encode(program, allocation);

        std::cout << "\nEncoded program:\n";

        for (std::size_t i = 0; i < words.size(); ++i) {
            std::cout << std::dec << i << ": 0x"
                      << std::hex << std::uppercase
                      << std::setw(8) << std::setfill('0')
                      << words[i] << '\n';
        }

        std::cout << std::dec << std::setfill(' ')
                  << "Program words: "
                  << words.size() << '\n';

        // 6. Reference execution
        const auto registers = execute(words);

        std::cout << "\nReference result: R"
                  << allocation.output_reg
                  << " = "
                  << registers.at(allocation.output_reg)
                  << '\n';

        // 7. Export generated instructions
        const std::filesystem::path output_path(
            output_prefix
        );

        if (output_path.has_parent_path()) {
            std::filesystem::create_directories(
                output_path.parent_path()
            );
        }

        export_program(
            words,
            allocation.output_reg,
            output_prefix
        );

        std::cout
            << "\nExported: "
            << output_prefix << ".txt, .h, .bin\n";

    } catch (const std::exception& error) {
        std::cerr << "Compilation failed: "
                  << error.what() << '\n';
        return 1;
    }

    return 0;
}
