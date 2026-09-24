cmake_minimum_required(VERSION 3.14)

add_subdirectory(../hal_bsp hal_bsp)

include(../hal_bsp/toolchain.cmake)

project(hal_app)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

add_executable(hal_app.elf)

target_sources(hal_app.elf
    PRIVATE
        main.c
)

target_include_directories(hal_app.elf
    PRIVATE
    PUBLIC
)

target_link_libraries(hal_app.elf
    PRIVATE
        -T "${BspLinkerScript}" -nostdlib
        "${ExtraArchiveLibraries}"
        -Wl,--start-group "${BspLibraryName}" -lc -lstdc++ -lgcc -lm -Wl,--end-group
)

# Create objdump from ELF.
set(objdump hal_app.elf.objdump)
add_custom_command(
    OUTPUT "${objdump}"
    DEPENDS hal_app.elf
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}" hal_app.elf >
            "${objdump}"
    COMMENT "Creating ${objdump}."
    VERBATIM
)
add_custom_target(create-objdump ALL DEPENDS "${objdump}")

# Report space free for stack + heap. Note that the file below is never created
# so the report is always output on build.
set(stack_report_file hal_app.elf.stack_report)
add_custom_command(
    OUTPUT "${stack_report_file}"
    DEPENDS hal_app.elf
    COMMAND niosv-stack-report -p "${ToolchainPrefix}" hal_app.elf
    COMMENT "Reporting memory available for stack + heap in hal_app.elf."
    VERBATIM
)
add_custom_target(niosv-stack-report ALL DEPENDS "${stack_report_file}")

# Generate HEX file(s) from hal_app.elf using elf2hex tool.
# Note : If ECC Full is enabled, width of 39 is set for NiosV TCM. Otherwise, 32.
add_custom_command(
    OUTPUT "onchip_memory2_0.hex"
    DEPENDS hal_app.elf
    COMMAND elf2hex hal_app.elf -o onchip_memory2_0.hex -b 0x00024000 -w 32 -e 0x00027FFF -r 4
    COMMENT "Creating onchip_memory2_0.hex."
    VERBATIM
)
add_custom_target(create-hex ALL DEPENDS "onchip_memory2_0.hex")
