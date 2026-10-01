# accelerator-compiler
---

#### This is an ongoing project

My goal here is to build a small FPGA-based accelerator and a compiler backend that maps computations to the custom hardware. The goal is to learn how AI accelerators work and how a compiler connects computations to the hardware's compute unit and memory.
I'm building it incrementally, starting with the processor-accelerator interface and scalar arithmetic, then adding tensor operations and compiler support as the project develops.

### Current Architecture
---

![high-level-architecture](./fpga/doc/images/diagram/high-level-architecture.png)
#### High Level Architecture
On a high-level, the Nios V CPU controls the system, fetching instructions and accessing data in on-chip RAM. It communicates with the host computer's JTAG console through the JTAG UART. A custom test register was used to verify the initial system connections, while the scalar unit supports addition, subtraction, and multiplication.

![scalar-unit-architecture](./fpga/doc/images/diagram/scalar_unit_architecture.png)
#### Scalar Unit Architecture
The scalar unit wraps an arithmetic unit with registers that the CPU can read and write. Its interfaces takes a 3-bit address, read and write signals, and 32-bit write data, and returns 32-bit read data.

The CPU first writes the two operands and an operation code into their registers. It then writes to the start address, which asserts input_valid and tells the arithmetic unit to compute using the stored inputs.

When the arithmetic unit produces a result, it asserts result_valid. The scalar unit captures the result in the result register and sets the status flag, result_available. The CPU can check this flag, read the result, and then write to the acknoledgment address. This asserts result_ack, clearing the status flag while leaving the stored result unchanged.

The table below shows what each address does when read or written
| Address | write | read |
| :--- | :---: | :---: |
| **000** | A | A |
| **001** | B | B |
| **010** | op | op |
| **011** | input_valid | - |
| **100** | - | result |
| **101** | - | result_valid |
| **110** | result_ack | - |
| **111** | - | - |

To see complete RTL, go to: fpga/doc/quartus-rtl

### Demo Output
---

![addition](./fpga/doc/images/demo-output/addition.png)

![subtraction](./fpga/doc/images/demo-output/subtraction.png)

![multiplication](./fpga/doc/images/demo-output/multiplication-reset.png)

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
│   └── doc/                    # diagrams, images, & documentation
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