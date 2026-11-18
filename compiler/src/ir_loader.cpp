#include "ir_loader.h"

#include <cstdint>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <climits>
#include <limits>

namespace accel {
namespace {

int parse_value(const std::string& token) { // convert v0 to 0
    // verify token starts with v -> extract digits -> ensure all chars are digits -> convert str to int
    if (token.size() < 2 || token[0] != 'v') {
        throw std::runtime_error("Expected value ID like v0, got: " + token);
    }

    const std::string digits = token.substr(1);

    if (digits.empty() || digits.find_first_not_of("0123456789") != std::string::npos) {
        throw std::runtime_error("Invalid value ID: " + token);
    }

    unsigned long long value = std::stoull(digits);

    if (value > INT_MAX) {
        throw std::runtime_error("Value ID out of range: " + token);
    }

    return static_cast<int>(value);
}

// parse signed/unsigned 32-bit bit patterns
uint32_t parse_immediate(const std::string& token) {
    std::size_t pos = 0;

    if (!token.empty() && token[0] == '-') {
        long long value = std::stoll(token, &pos, 0);

        if (pos != token.size() || value < INT32_MIN || value > INT32_MAX) {
            throw std::runtime_error("Immediate out of range: " + token);
        }
        return static_cast<uint32_t>(value);
    }

    unsigned long long value = std::stoull(token, &pos, 0);

    if (pos != token.size() || value > INT32_MAX) {
        throw std::runtime_error("Immediate out of range: " + token);
    }
    return static_cast<uint32_t>(value);
}

void require_end(std::istringstream& stream) {
    std::string extra;

    if (stream >> extra) {
        throw std::runtime_error("unexpected token: " + extra);
    }
}

}   // namespace

Program load_ir(const std::string& path) {
    std::ifstream file(path);

    if (!file) {
        throw std::runtime_error("Cannot open IR file: " + path);
    }

    Program program{};
    bool has_output = false;

    std::string line;
    std::size_t line_number = 0;

    while(std::getline(file, line)) {
        line_number++;

        // remove comments
        auto comment = line.find('#');
        if (comment != std::string::npos) {
            line.erase(comment);
        }

        std::istringstream stream(line);
        std::string opcode;

        if (!(stream >> opcode)) {
            continue;
        }

        try {
            if (opcode == "output") {
                std::string result;

                if (!(stream >> result)) {
                    throw std::runtime_error("output requires a value id");
                }

                if (has_output) {
                    throw std::runtime_error("duplicate output declaration");
                }

                program.output = parse_value(result);
                has_output = true;
                require_end(stream);
                continue;
            }

            if (has_output) {
                throw std::runtime_error("operations must precede output");
            }

            Operation op{};

            if (opcode == "const") {
                std::string result, immediate;

                if (!(stream >> result >> immediate)) {
                    throw std::runtime_error("expected: const vN immediate");
                }

                op.kind = OpKind::Constant;
                op.result = parse_value(result);
                op.immediate = parse_immediate(immediate);
            } else if (opcode == "add" || opcode == "sub" || opcode == "mul") {
                std::string result, lhs, rhs;

                if (!(stream >> result >> lhs >> rhs)) {
                    throw std::runtime_error("expected: op vDst vLhs vRhs");
                }

                op.kind = opcode == "add" ? OpKind::Add :
                            opcode == "sub" ? OpKind::Sub :
                                                OpKind::Mul;

                op.result = parse_value(result);
                op.lhs = parse_value(lhs);
                op.rhs = parse_value(rhs);
            } else {
                throw std::runtime_error("unknown opcode: " + opcode);
            }

            require_end(stream);
            program.operations.push_back(op);
        } catch (const std::exception& error) {
            throw std::runtime_error(path + ":" + std::to_string(line_number) + ": " + error.what());
        }
    }

    if (!file.eof() && file.fail()) {
        throw std::runtime_error("error while loading: " + path);
    }

    if (!has_output) {
        throw std::runtime_error(path + ": missing output declaration");
    }
    return program;
}
}   // namespace accel