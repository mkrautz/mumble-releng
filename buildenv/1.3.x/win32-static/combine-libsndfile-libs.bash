#!/bin/bash -ex
# Copyright 2013-2014 The 'mumble-releng' Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file in the source tree or at
# <http://mumble.info/mumble-releng/LICENSE>.

# If we're on Visual Studio 2013 or greater, take the easy path:
# we combine multiple native MSVC static libs into a single one.
#
# If we can't take this path, we fall back to creating an amalgamation
# of MSVC and MinGW libs by extracting object files from the archives
# and followed 
if [ $VSMAJOR -ge 12 ]; then
	if [ ${MUMBLE_BUILD_USE_LTCG} -eq 1 ]; then
		LTCG_FLAG="/ltcg"
	fi
	cmd /c lib.exe ${LTCG_FLAG} /out:$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libsndfile-1.lib) \
		"$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libFLAC.a)" \
		"$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libogg.a)" \
		"$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libvorbis.a)" \
		"$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libvorbisfile.a)" \
		"$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libsndfile.a)"
else
	TEMPDIR=$(mktemp -d)
	cd "${TEMPDIR}"

	# Create an object file with the magic SafeSEH symbol.
	# The symbol '@feat.00' with a value of 1 signals to link.exe
	# that the object file is compatible with the safe exception
	# handling feature.
	echo "" | i686-pc-mingw32-as --defsym @feat.00=1 -o safeseh.o

	# extract_mingw_obj takes two arguments:
	#  1. An absolute path to to a statlic library (.a)
	#     whose objects shall be extracted.
	#  2. A short name which will be used as the name of directory
	#     (in CWD) to hold the resulting object files, as well as
	#     the prefix for the object files.
	# 
	# It extracts all object files from the archive, and
	# prepends "${SHORT_NAME}___" to their file name. This
	# namespacing is done to allow us to merge the object
	# files from multiple static libraries without fearing
	# name clashes.
	#
	# The resulting, prefixed, object files will also be
	# marked as SafeSEH compatible.
	function extract_mingw_obj {
	        ABS_ARCHIVE=${1}
	        SHORT_NAME=${2}

	        mkdir -p ${SHORT_NAME}
	        cd ${SHORT_NAME}

	        i686-pc-mingw32-ar x "${ABS_ARCHIVE}"
	        for fn in `ls`; do
	                # Combine the original object with safeseh.o to mark the resulting
	                # object as SafeSEH compatible.
	                i686-pc-mingw32-ld -r ../safeseh.o ${fn} -o ${SHORT_NAME}___${fn}
	                rm -f ${fn}
	        done
	        cd ..
	}

	# extract_msvc_obj takes the same arguments as extract_mingw_obj above.
	#
	# It extracts the .obj files from Ogg, Vorbis and FLAC static libraries
	# built with Visual Studio and
	#
	#  1. Ensures object filename uniqueness.
	#  2. Flattens the directory hierarchy.
	#
	# Some of its beheavior (the directory structure it expects), is hard-coded
	# for our own Ogg/Vorbis/FLAC builds, so if you're going to use this with
	# more than those libraries, you will probably need to make this more
	# generic.
	function extract_msvc_obj {
		ABS_ARCHIVE=${1}
		SHORT_NAME=${2}

		mkdir -p ${SHORT_NAME}
		cd ${SHORT_NAME}

		mkdir -p Win32/Release                # libogg and libvorbis
		mkdir -p Release Release_static ia32  # FLAC
		mkdir -p Default/obj/libsndfile       # libsndfile

		i686-pc-mingw32-ar x "${ABS_ARCHIVE}"
		for fn in `/usr/bin/find . -name "*.obj"`; do
			basefn=$(basename ${fn})
			mv ${fn} ${SHORT_NAME}___${basefn}
		done
		cd ..
	}

	extract_mingw_obj "$(i686-pc-mingw32-gcc --print-libgcc)" libgcc
	extract_mingw_obj "$(i686-pc-mingw32-gcc --print-sysroot)/mingw/lib/libmingwex.a" libmingwex
	extract_msvc_obj "${MUMBLE_SNDFILE_PREFIX}/lib/libFLAC.a" flac
	extract_msvc_obj "${MUMBLE_SNDFILE_PREFIX}/lib/libogg.a" ogg
	extract_msvc_obj "${MUMBLE_SNDFILE_PREFIX}/lib/libvorbis.a" vorbis
	extract_msvc_obj "${MUMBLE_SNDFILE_PREFIX}/lib/libvorbisfile.a" vorbisfile
	extract_mingw_obj "${MUMBLE_SNDFILE_PREFIX}/lib/libsndfile.a" sndfile

	# Combine all the extracted objects into 'libsndfile-1.lib'.
	# This name is the same that the Win32 DLL distribution of libsndfile
	# uses, allowing this static version to be a drop-in replacement.
	rm -f "${MUMBLE_SNDFILE_PREFIX}/lib/libsndfile-1.lib"
	cmd /c lib.exe /ltcg /out:$(cygpath -w ${MUMBLE_SNDFILE_PREFIX}/lib/libsndfile-1.lib) \
		libgcc\\\*.o \
		libmingwex\\\*.o \
		flac\\\*.obj \
		ogg\\\*.obj \
		vorbis\\\*.obj \
		vorbisfile\\\*.obj \
		sndfile\\\*.o
	rm -rf "${TEMPDIR}"
fi
