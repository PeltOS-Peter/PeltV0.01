# ==============================================
# makefile version: v0.6
#  Created on: Mar 21, 2026
#      Author: Peter Innovation Studio
# =============================================================================
# Pelt OS Build System (Static Library Integration)
# Structure: 
#   - lib_src/    -> obj_lib/ -> libpelt.a
#   - stub_src/   -> obj/
#   - kernel_src/ -> obj/
# =============================================================================

CC = x86_64-elf-gcc
CXX = x86_64-elf-g++
AS = nasm
LD = x86_64-elf-ld
# Archiver
AR      := ar
# --- Compilation Flags ---
# NOTE: Using -m32 for the stub. 
# Removed -mcmodel=kernel and -mno-red-zone as they are for 64-bit mode only.
COMMON_FLAGS = -I$(INC_DIR) -ffreestanding -O2 -Wall -Wextra -fno-stack-protector -fno-pic -m32

CFLAGS = $(COMMON_FLAGS)
CPPFLAGS = $(COMMON_FLAGS) -fno-exceptions -fno-rtti

# -m elf_i386: Required to link 32-bit objects using a 64-bit cross-linker.
LDFLAGS = -T $(SCRIPT_DIR)/linker.ld -nostdlib -m elf_i386

# --- Project Structure ---
SRC_DIR = stub_src
CLIB_DIR = pi_c_lib
CLIB_OBJ_DIR = clibobj
BUILD_DIR = build
BIN_DIR = bin
INC_DIR = include
SCRIPT_DIR = scripts
TARGET = $(BIN_DIR)/peltx86.iso
STUB_BIN = $(BIN_DIR)/stub_pelt.elf
GRUB_CONFIG = $(SCRIPT_DIR)/grub.cfg
CLIB = pi_c_lib.a

LIB32 = peltLib32.a
SRC_LIB32 = srcLib32
LIB32_OBJ_DIR = objLib32

LIB32_CS   = $(wildcard $(SRC_LIB32)/*.c)
LIB32_CPPS   = $(wildcard $(SRC_LIB32)/*.cpp)
LIB32_ASMS  = $(wildcard $(SRC_LIB32)/*.asm)

LIB32_C_FLAGS = -I$(INC_DIR) -ffreestanding -O2 -Wall -Wextra -fno-stack-protector -fno-pic -m32
LIB32_CPP_FLAGS = $(LIB32_C_FLAGS) -fno-exceptions -fno-rtti

LIB32_OBJS    = $(LIB32_CS:$(SRC_LIB32)/%.c=$(LIB32_OBJ_DIR)/%.o) \
				$(LIB32_ASMS:$(SRC_LIB32)/%.asm=$(LIB32_OBJ_DIR)/%.o) \
				$(LIB32_CPPS:$(SRC_LIB32)/%.cpp=$(LIB32_OBJ_DIR)/%.o)

LIBS = $(CLIB) $(LIB32)

# ... (Keep other directory definitions) ...

# --- File Discovery ---
# Use separate variables to avoid filename collisions in OBJECTS.
STUB_CS   = $(wildcard $(SRC_DIR)/*.c)
STUB_CPPS = $(wildcard $(SRC_DIR)/*.cpp)
STUB_ASMS = $(wildcard $(SRC_DIR)/*.asm)

CLIB_CS   = $(wildcard $(CLIB_DIR)/*.c)
CLIB_ASM  = $(wildcard $(CLIB_DIR)/*.asm)

OBJECTS = $(STUB_CS:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o) \
          $(STUB_CPPS:$(SRC_DIR)/%.cpp=$(BUILD_DIR)/%.o) \
          $(STUB_ASMS:$(SRC_DIR)/%.asm=$(BUILD_DIR)/%.o)

CLIB_OBJS = $(CLIB_CS:$(CLIB_DIR)/%.c=$(CLIB_OBJ_DIR)/%.o) \
          $(CLIB_ASM:$(CLIB_DIR)/%.asm=$(CLIB_OBJ_DIR)/%.o)

# --- Targets ---

all: $(TARGET)

$(TARGET): $(STUB_BIN) $(GRUB_CONFIG) $(LIBS)
	@mkdir -p iso/boot/grub
	cp $(STUB_BIN) iso/boot/
	cp $(GRUB_CONFIG) iso/boot/grub/grub.cfg
	grub-mkrescue -o $(TARGET) iso

$(LIB32): $(LIB32_OBJS)
	@echo "Creating static library: $@"
	@mkdir -p $(dir $@)
	$(AR) rcs $@ $^

$(LIB32_OBJ_DIR)/%.o: $(SRC_LIB32)/%.asm
	@mkdir -p $(dir $@)
	$(AS) -f elf32 $< -o $@

$(LIB32_OBJ_DIR)/%.o: $(SRC_LIB32)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(LIB32_C_FLAGS) -c $< -o $@

$(LIB32_OBJ_DIR)/%.o: $(SRC_LIB32)/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(LIB32_CPP_FLAGS) -c $< -o $@


$(CLIB): $(CLIB_OBJS)
	@echo "Creating static library: $@"
	@mkdir -p $(dir $@)
	$(AR) rcs $@ $^

$(CLIB_OBJ_DIR)/%.o: $(CLIB_DIR)/%.asm
	@mkdir -p $(dir $@)
	$(AS) -f elf32 $< -o $@

$(CLIB_OBJ_DIR)/%.o: $(CLIB_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(STUB_BIN): $(OBJECTS) $(LIBS)
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) $(OBJECTS) $(LIBS) -o$@

# Compile C++ Stub files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) -c $< -o $@

# Compile C Stub files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble 32-bit Boot files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(dir $@)
	$(AS) -f elf32 $< -o $@

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) iso