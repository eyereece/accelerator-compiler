# accelerator-compiler
---

#### This is an ongoing project

I'm building a small FPGA-based accelerator and a compiler backend that maps computations to custom hardware. Through this project, I want to understand how AI accelerators work and how compilers map operations and data to their compute units and memory.

I'm developing it incrementally, starting with the processor-accelerator interface and scalar arithmetic, then adding tensor operations and compiler support as the project progresses.

#### Implementation Details
I have written a series of articles on the implementation details of the project available here:
1. [Building an FPGA accelerator and its compiler](https://www.joankusuma.com/post/building-an-fpga-accelerator-and-its-compiler)
2. [My FPGA Scalar Compute Unit Architecture](https://www.joankusuma.com/post/my-fpga-scalar-compute-unit-architecture)
3. Compiler implementation writeup in-progress

### Hardware Architecture
---

![high-level-architecture](./doc/images/diagram/high-level-architecture.png)
#### High Level Architecture
At a high level, the Nios V/m CPU controls the system and runs its software from external SDRAM through the SDRAM controller. The JTAG UART provides console communication with the computer.

The accelerator’s top-level module, `controller_unit`, connects the CPU interface to three modules: `instruction_ram`, `execution_controller`, and `scalar_unit`. The accelerator has its own instruction memory, separate from the external SDRAM used by Nios. This memory stores up to 512 32-bit words containing instructions and immediate values.

Nios loads an accelerator program into instruction RAM, sets its length, and starts execution through the following word addresses:

| Word address | Write | Read |
| :--- | :--- | :--- |
| 0 | Start when `writedata[0] = 1` | 0 |
| 1 | Ignored | Status: `busy` (bit 0), `done` (bit 1), `error` (bit 2) |
| 2 | Program length, including immediate words | Program length |
| 8–15 | Ignored | Registers R0–R7 |
| 512–1023 | Instruction RAM words 0–511 | 0 |

These addresses are relative to the controller unit; their CPU byte offsets are the word addresses multiplied by four. Program writes, length changes, and additional start requests are ignored while execution is busy.

After launch, `execution_controller` sequences the program independently. It maintains a program counter and eight 32-bit registers, R0–R7, and fetches instructions from instruction RAM. Each instruction has the following layout:

| Bits | Field | Purpose |
| :--- | :--- | :--- |
| 31–28 | Opcode | Selects the instruction |
| 27–25 | Destination register | Register receiving the result |
| 24–22 | Source A register | First arithmetic operand |
| 21–19 | Source B register | Second arithmetic operand |
| 18–0 | Unused | Ignored by the hardware |

The execution controller decodes the opcode in bits 31–28:

| Opcode | Instruction | Action |
| :--- | :--- | :--- |
| `0000` | HALT | Stop execution and set `done` |
| `0001` | LOAD_IMM | Load the next RAM word into the destination register |
| `0010` | ADD | Add the two source registers |
| `0011` | SUB | Subtract source B from source A |
| `0100` | MUL | Multiply the two source registers |

For `LOAD_IMM`, the next RAM word is treated as a full 32-bit value, so the instruction consumes two words. For arithmetic instructions, the execution controller reads the source registers and translates the opcode into the scalar unit’s 2-bit operation code: `00` for addition, `01` for subtraction, or `10` for multiplication.

The `scalar_unit` captures the operands and operation code and passes them to `scalar_arith_unit`, which performs the calculation. The scalar unit returns the result with a completion signal, and the execution controller writes it into the destination register before fetching the next instruction.

Nios polls the execution status while the accelerator runs. Execution stops when the controller encounters `HALT` or detects an error, such as an unsupported opcode or a fetch beyond the program length. Nios can then read the final values from R0–R7. The `done` and `error` flags remain set until reset or the next accepted start request.

The diagram below shows the execution controller’s states and the transitions between them.
![fsm-controller-unit](./doc/images/diagram/fsm-execution-controller.png)

For more detailed diagrams, go to this folder: .\doc\images\diagram

### Compiler Backend
---

The compiler backend is implemented in C++17 using only the STL. Programs are currently constructed directly in a small IR, without a parser. Each operation defines a logical value, and the program identifies which value to return as its output. Supported operations are constants, addition, subtraction, and multiplication using 32-bit integer arithmetic.

The current implementation includes:

- **IR validation:** Checks for duplicate definitions, undefined operands and outputs, self-references, forward references, and unsupported operations.
- **Basic register allocation:** Assigns a separate hardware register to each result in operation order. Programs with more than eight results are rejected; register reuse are not yet supported.
- **Instruction encoding:** Converts constants into `LOAD_IMM` instructions followed by their values, encodes `ADD`, `SUB`, and `MUL`, and appends `HALT`. The encoder enforces the instruction RAM’s 512-word limit.
- **Reference execution:** Executes encoded instructions in C++, modeling the accelerator’s eight registers and 32-bit wraparound arithmetic. Detects invalid opcodes, missing immediate words, missing `HALT`, and invalid program lengths.
- **Program export:** Generates `program.txt` with a readable instruction listing, `program.h` with the instruction array, word count, and output-register index, and `program.bin` with explicitly little-endian instruction words.
- **Software tests:** 29 passing tests cover arithmetic and wraparound, exact instruction encoding, IR validation, register exhaustion, malformed instruction streams, and executor edge cases.

The first end-to-end program, `(7 + 3) × 2`, compiles into nine instruction words and produces `R4 = 20` in both the C++ reference executor and on the FPGA. This completes the path from directly constructed IR through validation, register allocation, encoding, and the Nios loader to accelerator execution.

The current board workflow is to build and run the host compiler, copy the generated `program.h` into `hal_app`, then rebuild and run the Nios application. BSP regeneration and FPGA rebuilding are unnecessary while the hardware interface remains unchanged. The loader checks completion, hardware errors, and a polling timeout, but its expected result is still manually defined in `main.c`.

Next steps are to export expected results, add an independent IR evaluator and repeatable randomized tests, and build a reusable board test runner. Liveness-based register reuse will follow, allowing programs with more than eight total results when their simultaneously live values fit in the available registers.

### Demo Output
---
<b>Hardware Demo: running compiler-generated instructions</b>
![system-demo-output](./doc/images/demo-output/system-demo-output.png)


<b>Compiler Demo output</b>
![compiler-demo-output](./doc/images/demo-output/compiler-output.png)


The compiler generates:
* program.txt: Readable instruction listing for debugging.
* program.h: C header used by the host application to load and run instructions on the FPGA.
* program.bin: Raw binary instructions for potential future file-based loading. (not currently used in the workflow)

The video below shows the DE10-lite board running the current design, along with a simple LED animation.

https://github.com/user-attachments/assets/8b566521-1c05-4bad-a8dc-58d336d68ac6

### Codebase Directory
---

```
accelerator-compiler
├── fpga/
│   ├── accel/
│       ├── accel/              # generated Platform Designer system files
│       ├── rtl/                # custom hardware modules
│       ├── software/hal_app    # C application running on Nios V
|       └── tb/                 # RTL testbenches
├── compiler/
│   ├── include/                # C++ headers
|   ├── src/                    # compiler code
|   └── tests/                  # unit tests
├── doc/                        # diagrams, images, & notes
├── .gitignore
├── LICENSE
└── README.md
```

### Build and Run
---

The steps below outline how to build the current design and run the C application on the DE10-Lite board

| File | Purpose |
| :--- | :---: |
| **accel.qpf** | Quartus project file |
| **accel.qsf** | project settings, device selection, & pin assignment |
| **fpga_top.sdc** | timing constraints |
| **accel.qsys** | Platform Designer system definition |

Software used:
* Quartus Prime Lite 25.1
* Platform Designer
* Quartus Programmer
* Nios V Command Shell & niosv-bsp-editor
* Ashling RiscFree IDE
* juart-terminal (for viewing console output)
* Questa for RTL simulation (requires a separate free license)

Build & program the hardware:
* Open accel.qpf in Quartus Prime
* Open accel.qsys in Platform Designer and generate HDL
* Make sure fpga_top.v is included in the project and fpga_top is set as the top-level module
* Run Full Compilation
* Open Quartus Programmer and program the board using the generated .sof file

Build & run the software
* Launch niosv-bsp-editor from the Nios V Command Shell and generate the BSP
* Import the Nios V application project into Ashling
* Build and run hal_app on the board
* Open juart-terminal to view the output
