#include "enc.h"
#include "exec.h"
#include "ir.h"
#include "reg_alloc.h"
#include "validate.h"

#include <cstdint>
#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

void check(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

// Pass only if the expected error is raised.
template <typename Function>
void expect_error(Function action, const std::string& expected) {
    try {
        action();
    } catch (const std::runtime_error& error) {
        check(
            std::string(error.what()).find(expected) != std::string::npos,
            "Unexpected error: " + std::string(error.what())
        );
        return;
    }

    throw std::runtime_error(
        "Expected an error containing: " + expected
    );
}

// Run the complete software pipeline.
std::uint32_t run(const accel::Program& program) {
    const auto allocation = accel::allocate_reg(program);
    const auto words = accel::encode(program, allocation);
    const auto registers = accel::execute(words);

    return registers.at(allocation.output_reg);
}

accel::Program binary(
    accel::OpKind kind,
    std::uint32_t a,
    std::uint32_t b
) {
    // Value IDs deliberately differ from register numbers.
    return {
        {
            {accel::OpKind::Constant, 10, 0, 0, a},
            {accel::OpKind::Constant, 20, 0, 0, b},
            {kind, 30, 10, 20}
        },
        30
    };
}

accel::Program constants(std::uint32_t count) {
    accel::Program program{{}, count - 1};

    for (std::uint32_t i = 0; i < count; ++i) {
        program.operations.push_back(
            {accel::OpKind::Constant, i, 0, 0, i + 100}
        );
    }

    return program;
}

struct Runner {
    unsigned passed = 0;
    unsigned failed = 0;

    template <typename Function>
    void test(const char* name, Function action) {
        try {
            action();
            ++passed;
            std::cout << "PASS: " << name << '\n';
        } catch (const std::exception& error) {
            ++failed;
            std::cerr << "FAIL: " << name
                      << ": " << error.what() << '\n';
        } catch (...) {
            ++failed;
            std::cerr << "FAIL: " << name
                      << ": unexpected exception\n";
        }
    }
};

} // namespace

int main() {
    Runner tests;

    tests.test("ADD", [] {
        check(
            run(binary(accel::OpKind::Add, 7, 3)) == 10,
            "Expected 10"
        );
    });

    tests.test("SUB operand order", [] {
        check(
            run(binary(accel::OpKind::Sub, 7, 3)) == 4,
            "Expected 4"
        );
    });

    tests.test("MUL", [] {
        check(
            run(binary(accel::OpKind::Mul, 7, 3)) == 21,
            "Expected 21"
        );
    });

    tests.test("ADD overflow", [] {
        check(
            run(binary(accel::OpKind::Add, 0xffffffffu, 1)) == 0,
            "Expected 0"
        );
    });

    tests.test("SUB underflow", [] {
        check(
            run(binary(accel::OpKind::Sub, 0, 1)) == 0xffffffffu,
            "Expected 0xffffffff"
        );
    });

    tests.test("MUL overflow", [] {
        check(
            run(binary(accel::OpKind::Mul, 0xffffffffu, 2))
                == 0xfffffffeu,
            "Expected low 32 bits"
        );
    });

    tests.test("MUL wraps to zero", [] {
        check(
            run(binary(accel::OpKind::Mul, 0x10000u, 0x10000u)) == 0,
            "Expected 0"
        );
    });

    tests.test("Opcode-like constants are data", [] {
        const std::vector<std::uint32_t> values{
            0u,
            0x10000000u,
            0x24080000u,
            0x30000000u,
            0x48980000u,
            0xf0000000u
        };

        for (const std::uint32_t value : values) {
            const accel::Program program{
                {{accel::OpKind::Constant, 42, 0, 0, value}},
                42
            };

            check(run(program) == value, "Immediate was not preserved");
        }
    });

    tests.test("Example exact encoding and result", [] {
        const accel::Program program{
            {
                {accel::OpKind::Constant, 0, 0, 0, 7},
                {accel::OpKind::Constant, 1, 0, 0, 3},
                {accel::OpKind::Add, 2, 0, 1},
                {accel::OpKind::Constant, 3, 0, 0, 2},
                {accel::OpKind::Mul, 4, 2, 3}
            },
            4
        };

        const auto allocation = accel::allocate_reg(program);

        const std::vector<std::uint32_t> expected{
            0x10000000u,
            7,
            0x12000000u,
            3,
            0x24080000u,
            0x16000000u,
            2,
            0x48980000u,
            0
        };

        check(
            accel::encode(program, allocation) == expected,
            "Encoding mismatch"
        );
        check(allocation.output_reg == 4, "Expected output R4");
        check(run(program) == 20, "Expected 20");
    });

    tests.test("Output can be an earlier value", [] {
        auto program = binary(accel::OpKind::Add, 7, 3);
        program.output = 20;

        check(run(program) == 3, "Expected the selected output value");
    });

    tests.test("Duplicate definition", [] {
        expect_error([] {
            accel::validate({
                {
                    {accel::OpKind::Constant, 0},
                    {accel::OpKind::Constant, 0}
                },
                0
            });
        }, "Duplicate definition");
    });

    tests.test("Undefined left operand", [] {
        expect_error([] {
            accel::validate({
                {
                    {accel::OpKind::Constant, 0},
                    {accel::OpKind::Add, 1, 9, 0}
                },
                1
            });
        }, "undefined left operand");
    });

    tests.test("Undefined right operand", [] {
        expect_error([] {
            accel::validate({
                {
                    {accel::OpKind::Constant, 0},
                    {accel::OpKind::Add, 1, 0, 9}
                },
                1
            });
        }, "undefined right operand");
    });

    tests.test("Self-reference", [] {
        expect_error([] {
            accel::validate({
                {
                    {accel::OpKind::Constant, 0},
                    {accel::OpKind::Add, 1, 1, 0}
                },
                1
            });
        }, "undefined left operand");
    });

    tests.test("Forward reference", [] {
        expect_error([] {
            accel::validate({
                {
                    {accel::OpKind::Constant, 0},
                    {accel::OpKind::Add, 1, 0, 2},
                    {accel::OpKind::Constant, 2}
                },
                1
            });
        }, "undefined right operand");
    });

    tests.test("Undefined output", [] {
        expect_error([] {
            accel::validate({
                {{accel::OpKind::Constant, 0}},
                9
            });
        }, "is not defined");
    });

    tests.test("Unsupported IR kind", [] {
        expect_error([] {
            accel::validate({
                {{static_cast<accel::OpKind>(99), 0}},
                0
            });
        }, "Unknown operation kind");
    });

    tests.test("Eight results fit", [] {
        check(run(constants(8)) == 107, "Expected R7 = 107");
    });

    tests.test("Ninth result exhausts registers", [] {
        expect_error([] {
            accel::allocate_reg(constants(9));
        }, "all 8 registers");
    });

    tests.test("Invalid opcode", [] {
        expect_error([] {
            accel::execute({0xf0000000u, 0});
        }, "Invalid opcode");
    });

    tests.test("Missing immediate", [] {
        expect_error([] {
            accel::execute({0x10000000u});
        }, "Missing LOAD_IMM data");
    });

    tests.test("Missing HALT after immediate", [] {
        expect_error([] {
            accel::execute({0x10000000u, 7});
        }, "without HALT");
    });

    tests.test("Missing HALT after arithmetic", [] {
        expect_error([] {
            accel::execute({0x20000000u});
        }, "without HALT");
    });

    tests.test("Empty stream", [] {
        expect_error([] {
            accel::execute({});
        }, "1 - 512 words");
    });

    tests.test("Oversized stream", [] {
        expect_error([] {
            accel::execute(std::vector<std::uint32_t>(513, 0));
        }, "1 - 512 words");
    });

    tests.test("HALT ignores trailing words and unused bits", [] {
        const auto registers = accel::execute({
            0x0fffffffu,
            0xf0000000u
        });

        for (const auto value : registers) {
            check(value == 0, "Expected cleared registers");
        }
    });

    tests.test("Registers reset between executions", [] {
        check(
            accel::execute({0x10000000u, 9, 0})[0] == 9,
            "Expected writable R0"
        );
        check(
            accel::execute({0})[0] == 0,
            "Expected fresh R0"
        );
    });

    tests.test("Destination may equal source", [] {
        check(
            accel::execute({0x10000000u, 7, 0x20000000u, 0})[0] == 14,
            "Expected R0 + R0 to write R0"
        );
    });

    tests.test("HALT at final RAM word", [] {
        std::vector<std::uint32_t> words(512, 0x20000000u);
        words.back() = 0;

        check(
            accel::execute(words)[0] == 0,
            "Expected successful HALT"
        );

        words.back() = 0x20000000u;

        expect_error([&words] {
            accel::execute(words);
        }, "without HALT");
    });

    std::cout << '\n'
              << tests.passed << " passed, "
              << tests.failed << " failed\n";

    return tests.failed == 0 ? 0 : 1;
}