INC_DIR=/opt/Cadence/INCISIV/cur/tools/include
CC=gcc
OCD=~/devel/openocd/build/bin/openocd
SOURCE_DIR:=$(shell pwd)/..
TEST_DIR=$(SOURCE_DIR)/test
CACHE_DIR=$(TEST_DIR)/cache

# Set V=1 when calling make to enable verbose output
# mainly for debugging purposes.
ifeq ($(V), 1)
Q=
QUIET=
else
Q ?=@
QUIET=-quiet
endif

C_SRC = $(SOURCE_DIR)/jtag_dpi.c
SV_SRC ="$(SOURCE_DIR)/jtag_dpi.sv \
				 $(SOURCE_DIR)/test/adv_dbg_if/rtl/adbg_tap_top.v \
				 $(SOURCE_DIR)/test/test.sv \
"

all: build

jtag_dpi.so:
	@echo '##### Building DPI object ######'
	mkdir -p $(CACHE_DIR)
	$(Q)cd $(CACHE_DIR); $(CC) -fPIC -shared -o jtag_dpi.so $(C_SRC) -I$(INC_DIR)

build: jtag_dpi.so
	#$(Q)iverilog-vpi $(IVERILOG_VPI_SRC) > /dev/null
	#$(Q)iverilog -I$(INCLUDE_DIR) -ojtag_vpi_tb.vvp $(IVERILOG_SRC)

sim: build
	@echo '##### Start the simulation ######'
	#$(Q)vvp -n -M. -mjtag_vpi jtag_vpi_tb.vvp +jtag_vpi_enable=1 &
	mkdir -p $(CACHE_DIR)
	$(Q)cd $(CACHE_DIR); ncverilog +nc64bit +sv +sv_lib=jtag_dpi.so +access+r +incdir+"$(SOURCE_DIR)/test/adv_dbg_if/rtl/" -mccodegen +jtag_vpi_enable $(SV_SRC)
	@sleep 1
	#@echo '##### Running the test client ######'
	#$(Q)./test_client
	#@sleep 1

ocd: build
	mkdir -p $(CACHE_DIR)
	$(Q)cd $(CACHE_DIR); $(OCD) -d 3 -f $(TEST_DIR)/jtag_dpi.cfg

clean:
	@rm -rf $(CACHE_DIR)
