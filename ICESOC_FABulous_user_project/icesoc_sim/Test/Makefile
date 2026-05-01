MAX_BITBYTES=20000
FAB_PROJ_ROOT=../..
BUILD_DIR=build_icesoc
DESIGN=top
TESTBENCH=${DESIGN}_tb
TOP_WRAPPER=top_wrapper

FABRIC_FILES_DIR=${BUILD_DIR}/fabric_files_icesoc
USER_DESIGN_DIR=${FAB_PROJ_ROOT}/icesoc_sim/user_design_icesoc
USER_DESIGN_VERILOG=${USER_DESIGN_DIR}/${DESIGN}.v
TOP_WRAPPER_VERILOG=${USER_DESIGN_DIR}/${TOP_WRAPPER}.v
WAVEFORM_TYPE=fst

VVP_ARGS=+output_waveform=${BUILD_DIR}/${DESIGN}.${WAVEFORM_TYPE}
VVP_ARGS+=+bitstream_hex=${BUILD_DIR}/${DESIGN}.hex
VVP_ARGS+=+mem_hex=mem.hex
ifeq ($(WAVEFORM_TYPE),fst)
    VVP_ARGS+=-fst
endif

#only add if custom_prims.v exists
ifneq ($(wildcard ${USER_DESIGN_DIR}/custom_prims.v),)
		CUSTOM_PRIMS=-extra-plib ${USER_DESIGN_DIR}/custom_prims.v
endif

.PHONY: all build_test_design mkdir_build clean

build_test_design: run_yosys run_nextpnr run_bitgen copy_files

run_yosys: mkdir_build
	yosys -p "synth_fabulous -top ${TOP_WRAPPER} -json ${BUILD_DIR}/${DESIGN}.json ${CUSTOM_PRIMS}" ${USER_DESIGN_VERILOG} ${TOP_WRAPPER_VERILOG}

run_nextpnr: mkdir_build
	FAB_ROOT=${FAB_PROJ_ROOT} nextpnr-generic --uarch fabulous --json ${BUILD_DIR}/${DESIGN}.json -o fasm=${BUILD_DIR}/${DESIGN}.fasm

run_bitgen: mkdir_build
	bit_gen -genBitstream ${BUILD_DIR}/${DESIGN}.fasm ${FAB_PROJ_ROOT}/.FABulous/bitStreamSpec.bin ${BUILD_DIR}/${DESIGN}.bin
	python3 makehex.py ${BUILD_DIR}/${DESIGN}.bin ${MAX_BITBYTES} ${BUILD_DIR}/${DESIGN}.hex

copy_files: mkdir_build
	find ${FAB_PROJ_ROOT}/Tile/ -name '*.v' -type f ! -name '*_tile.v' -exec cp -n {} ${FABRIC_FILES_DIR}/ \;
	find ${FAB_PROJ_ROOT}/Fabric/ -name '*.v' -type f -exec cp -n {} ${FABRIC_FILES_DIR}/ \;
	find ${FAB_PROJ_ROOT}/icesoc_sim/rtl_icesoc_with_cores/ -name '*.v' -type f ! -path '*/original_fabric_files/*' -exec cp -n {} ${FABRIC_FILES_DIR}/ \;

mkdir_build:
	mkdir -p ${BUILD_DIR}
	mkdir -p ${FABRIC_FILES_DIR}

run_icesoc_simulation:
	iverilog -g2012 -s ${TESTBENCH} -o ${BUILD_DIR}/${DESIGN}.vvp ${FABRIC_FILES_DIR}/* ${USER_DESIGN_VERILOG} ${TESTBENCH}.v
	vvp ${BUILD_DIR}/${DESIGN}.vvp ${VVP_ARGS}

run_GTKWave:
	gtkwave ${BUILD_DIR}/${DESIGN}.${WAVEFORM_TYPE}

clean:
	rm -rf ${BUILD_DIR}