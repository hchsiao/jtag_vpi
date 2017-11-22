INC_DIR=/opt/Cadence/INCISIV/cur/tools/include
CC=gcc
OCD=~/devel/openocd/build/bin/openocd
SOURCE_DIR=../..
BENCH_DIR=$(SOURCE_DIR)/bench
#INCLUDE_DIR=$(BENCH_DIR)/include

# Set V=1 when calling make to enable verbose output
# mainly for debugging purposes.
ifeq ($(V), 1)
Q=
QUIET=
else
Q ?=@
QUIET=-quiet
endif

ADV_DEBUG_SRC = $(shell ls $(BENCH_DIR)/adv_debugsys/*.v)

C_SRC = $(SOURCE_DIR)/jtag_dpi.c
SV_SRC = $(SOURCE_DIR)/jtag_dpi.sv $(SOURCE_DIR)/test/test.sv

all: build

jtag_dpi.so:
	$(Q)$(CC) -fPIC -shared -o jtag_dpi.so $(C_SRC) -I$(INC_DIR)

build: jtag_dpi.so
	@echo '##### Building ######'
	#$(Q)$(CC) -otest_client $(BENCH_DIR)/test_client.c
	#$(Q)iverilog-vpi $(IVERILOG_VPI_SRC) > /dev/null
	#$(Q)iverilog -I$(INCLUDE_DIR) -ojtag_vpi_tb.vvp $(IVERILOG_SRC)

sim: build
	@echo '##### Start the simulation ######'
	#$(Q)vvp -n -M. -mjtag_vpi jtag_vpi_tb.vvp +jtag_vpi_enable=1 &
	$(Q)ncverilog +nc64bit +sv +sv_lib=jtag_dpi.so +access+r +incdir+"." -mccodegen +jtag_vpi_enable $(SV_SRC)
	@sleep 1
	#@echo '##### Running the test client ######'
	#$(Q)./test_client
	#@sleep 1

ocd: build
	$(Q)$(OCD) -f $(SOURCE_DIR)/sim/bin/jtag_dpi.cfg

clean:
	@rm -rf *.o *~ *.vpi *.vvp *.vcd test_client
