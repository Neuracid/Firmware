############################################################################
#
# Copyright (c) 2015 PX4 Development Team. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
# 3. Neither the name PX4 nor the names of its contributors may be
#    used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
############################################################################

#=============================================================================
#
#	Defined functions in this file
#
# 	OS Specific Functions
#
#		* px4_posix_add_firmware
#		* px4_posix_generate_builtin_commands
#		* px4_posix_add_export
#		* px4_posix_generate_romfs
#
# 	Required OS Inteface Functions
#
# 		* px4_os_add_flags
#		* px4_os_prebuild_targets
#

include(common/px4_base)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/posix)

#=============================================================================
#
#	px4_posix_generate_builtin_commands
#
#	This function generates the builtin_commands.c src for posix
#
#	Usage:
#		px4_posix_generate_builtin_commands(
#			MODULE_LIST <in-list>
#			OUT <file>)
#
#	Input:
#		MODULE_LIST	: list of modules
#
#	Output:
#		OUT	: generated builtin_commands.c src
#
#	Example:
#		px4_posix_generate_builtin_commands(
#			OUT <generated-src> MODULE_LIST px4_simple_app)
#
function(px4_posix_generate_builtin_commands)
	px4_parse_function_args(
		NAME px4_posix_generate_builtin_commands
		ONE_VALUE OUT
		MULTI_VALUE MODULE_LIST
		REQUIRED MODULE_LIST OUT
		ARGN ${ARGN})
	set(builtin_apps_string)
	set(builtin_apps_decl_string)
	set(command_count 0)
	foreach(module ${MODULE_LIST})
		# default
		set(MAIN_DEFAULT MAIN-NOTFOUND)
		set(STACK_DEFAULT 1024)
		set(PRIORITY_DEFAULT SCHED_PRIORITY_DEFAULT)
		foreach(property MAIN STACK PRIORITY)
			get_target_property(${property} ${module} ${property})
			if(NOT ${property})
				set(${property} ${${property}_DEFAULT})
			endif()
		endforeach()
		if (MAIN)
			set(builtin_apps_string
				"${builtin_apps_string}\tapps[\"${MAIN}\"] = ${MAIN}_main;\n")
			set(builtin_apps_decl_string
				"${builtin_apps_decl_string}extern int ${MAIN}_main(int argc, char *argv[]);\n")
			math(EXPR command_count "${command_count}+1")
		endif()
	endforeach()
	configure_file(${CMAKE_SOURCE_DIR}/cmake/posix/apps.h_in
		${OUT})
endfunction()

#=============================================================================
#
#	px4_os_add_flags
#
#	Set ths posix build flags.
#
#	Usage:
#		px4_os_add_flags(
#			C_FLAGS <inout-variable>
#			CXX_FLAGS <inout-variable>
#			EXE_LINKER_FLAGS <inout-variable>
#			INCLUDE_DIRS <inout-variable>
#			LINK_DIRS <inout-variable>
#			DEFINITIONS <inout-variable>)
#
#	Input:
#		BOARD					: flags depend on board/posix config
#
#	Input/Output: (appends to existing variable)
#		C_FLAGS					: c compile flags variable
#		CXX_FLAGS				: c++ compile flags variable
#		EXE_LINKER_FLAGS		: executable linker flags variable
#		INCLUDE_DIRS			: include directories
#		LINK_DIRS				: link directories
#		DEFINITIONS				: definitions
#
#	Example:
#		px4_os_add_flags(
#			C_FLAGS CMAKE_C_FLAGS
#			CXX_FLAGS CMAKE_CXX_FLAGS
#			EXE_LINKER_FLAG CMAKE_EXE_LINKER_FLAGS
#			INCLUDES <list>)
#
function(px4_os_add_flags)

	set(inout_vars
		C_FLAGS CXX_FLAGS EXE_LINKER_FLAGS INCLUDE_DIRS LINK_DIRS DEFINITIONS)

	px4_parse_function_args(
		NAME px4_add_flags
		ONE_VALUE ${inout_vars} BOARD
		REQUIRED ${inout_vars} BOARD
		ARGN ${ARGN})

	px4_add_common_flags(
		BOARD ${BOARD}
		C_FLAGS ${C_FLAGS}
		CXX_FLAGS ${CXX_FLAGS}
		EXE_LINKER_FLAGS ${EXE_LINKER_FLAGS}
		INCLUDE_DIRS ${INCLUDE_DIRS}
		LINK_DIRS ${LINK_DIRS}
		DEFINITIONS ${DEFINITIONS})

        set(PX4_BASE )
        set(added_include_dirs
		src/modules/systemlib
                src/lib/eigen
                src/platforms/posix/include
                mavlink/include/mavlink
                )

# Use the pthread instead of lpthread if the firmware is build for the parrot
# bebop. This resolves some linker errors in DriverFramework, when building a 
# static target.
if ("${BOARD}" STREQUAL "bebop")
  set(PX4_PTHREAD_BUILD "-pthread")
else()
  set(PX4_PTHREAD_BUILD "-lpthread")
endif()

if(UNIX AND APPLE)
        set(added_definitions
		-D__PX4_POSIX
		-D__PX4_DARWIN
		-D__DF_DARWIN
		-DCLOCK_MONOTONIC=1
		-Dnoreturn_function=__attribute__\(\(noreturn\)\)
		-include ${PX4_INCLUDE_DIR}visibility.h
                )

        set(added_exe_linker_flags
          ${PX4_PTHREAD_BUILD}
		)

else()

        set(added_definitions
		-D__PX4_POSIX
		-D__PX4_LINUX
		-D__DF_LINUX
		-DCLOCK_MONOTONIC=1
		-Dnoreturn_function=__attribute__\(\(noreturn\)\)
		-include ${PX4_INCLUDE_DIR}visibility.h
                )

        set(added_exe_linker_flags
		      ${PX4_PTHREAD_BUILD} -lrt
		)

endif()

if ("${BOARD}" STREQUAL "eagle" OR "${BOARD}" STREQUAL "excelsior")

	if ("$ENV{HEXAGON_ARM_SYSROOT}" STREQUAL "")
		message(FATAL_ERROR "HEXAGON_ARM_SYSROOT not set")
	else()
		set(HEXAGON_ARM_SYSROOT $ENV{HEXAGON_ARM_SYSROOT})
	endif()

	# Add the toolchain specific flags
        set(added_cflags ${POSIX_CMAKE_C_FLAGS} --sysroot=${HEXAGON_ARM_SYSROOT})
        set(added_cxx_flags ${POSIX_CMAKE_CXX_FLAGS} --sysroot=${HEXAGON_ARM_SYSROOT})

        list(APPEND added_exe_linker_flags
		-Wl,-rpath-link,${HEXAGON_ARM_SYSROOT}/usr/lib/arm-linux-gnueabihf
		-Wl,-rpath-link,${HEXAGON_ARM_SYSROOT}/lib/arm-linux-gnueabihf
		--sysroot=${HEXAGON_ARM_SYSROOT}
		)
elseif ("${BOARD}" STREQUAL "rpi" AND "$ENV{RPI_USE_CLANG}" STREQUAL "1")

	# Add the toolchain specific flags
	set(clang_added_flags
		-m32
		--target=arm-linux-gnueabihf
		-ccc-gcc-name arm-linux-gnueabihf
		--sysroot=${RPI_TOOLCHAIN_DIR}/gcc-linaro-arm-linux-gnueabihf-raspbian/arm-linux-gnueabihf/libc/)

	set(added_c_flags ${POSIX_CMAKE_C_FLAGS} ${clang_added_flags})
	set(added_cxx_flags ${POSIX_CMAKE_CXX_FLAGS} ${clang_added_flags})
	set(added_exe_linker_flags ${POSIX_CMAKE_EXE_LINKER_FLAGS} ${clang_added_flags})
else()
	# Add the toolchain specific flags
        set(added_cflags ${POSIX_CMAKE_C_FLAGS})
        set(added_cxx_flags ${POSIX_CMAKE_CXX_FLAGS})

endif()

	# output
	foreach(var ${inout_vars})
		string(TOLOWER ${var} lower_var)
		set(${${var}} ${${${var}}} ${added_${lower_var}} PARENT_SCOPE)
		#message(STATUS "posix: set(${${var}} ${${${var}}} ${added_${lower_var}} PARENT_SCOPE)")
	endforeach()

endfunction()

#=============================================================================
#
#	px4_os_prebuild_targets
#
#	This function generates os dependent targets
#
#	Usage:
#		px4_os_prebuild_targets(
#			OUT <out-list_of_targets>
#			BOARD <in-string>
#			)
#
#	Input:
#		BOARD 		: board
#		THREADS 	: number of threads for building
#
#	Output:
#		OUT	: the target list
#
#	Example:
#		px4_os_prebuild_targets(OUT target_list BOARD px4fmu-v2)
#
function(px4_os_prebuild_targets)
	px4_parse_function_args(
			NAME px4_os_prebuild_targets
			ONE_VALUE OUT BOARD THREADS
			REQUIRED OUT BOARD
			ARGN ${ARGN})
	add_custom_target(${OUT})
endfunction()
