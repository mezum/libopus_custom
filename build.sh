#!/bin/bash
# Copyright (c) 2020 Kosaki Mezumona
# This script distributed under the MIT License.
# See the root LICENSE file or https://opensource.org/licenses/MIT

# @(#)Build the libopus with opus_custom options.
# @(#)Usage:
# @(#)    [OPUSBUILD_CONF=CONF] \\
# @(#)    [OPUSBUILD_BUILD_DIR=BUILD_DIR]
# @(#)        bash build.sh TARGET TYPE OUTDIR
# @(#)Parameters:
# @(#)    TARGET: A target platform.
# @(#)        android_armv7
# @(#)        android_arm64
# @(#)        android_x86
# @(#)        android_x64
# @(#)        ios
# @(#)        macos
# @(#)    TYPE: The library type.
# @(#)        static
# @(#)        shared
# @(#)    OUTDIR: A directory path that is used to place built binaries.
# @(#)    CONF: The library configuration. (optional)
# @(#)        Debug
# @(#)        Release
# @(#)        MinSizeRel       (default)
# @(#)        RelWithDebInfo
# @(#)    BUILD_DIR: A directory path that is used to place intermediate files.

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"

__main__()
{
	set -ue
	if [[ $# -eq 0 ]]; then
		what "$0"
		return 1
	fi

	if [[ ! $# -eq 3 ]]; then
		echo "Invalid parameter count expected 3, but $#." >&2
		return 1
	fi

	local TARGET="$1"
	local TYPE="$2"
	local OUTDIR="$PWD/$3"
	shift 3

	local CONF="${OPUSBUILD_CONF:-MinSizeRel}"
	local BUILD_DIR="${OPUSBUILD_BUILD_DIR:-}"
	if [[ -z "$BUILD_DIR" ]]; then
		BUILD_DIR="$PWD/build"
	fi

	local TOOLCHAIN="$(cmake_toolchain "$TARGET")"
	if [[ ! -f "$TOOLCHAIN" ]]; then
		echo "Unknown target platform: $TARGET" >&2
		return 1
	fi

	eval "local GENERATOR_PARAMS=($(cmake_generator_params "$TARGET"))"

	local BUILD_SHARED_LIBS="$(cmake_build_type "$TYPE")"
	if [[ $BUILD_SHARED_LIBS -lt 0 ]]; then
		echo "Unknown library type: $TYPE"
		return 1
	fi

	mkdir -p "$BUILD_DIR"
	if [[ "$TARGET" == "ios" ]]; then
		export XCODE_XCCONFIG_FILE="$SCRIPT_DIR/polly/scripts/NoCodeSign.xcconfig"
	fi
	pushd "$BUILD_DIR" >/dev/null
	cmake "$SCRIPT_DIR/libopus" \
		-DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
		-DCMAKE_INSTALL_PREFIX="$OUTDIR" \
		-DCMAKE_BUILD_TYPE="$CONF" \
		-DBUILD_SHARED_LIBS="$BUILD_SHARED_LIBS" \
		-DOPUS_CUSTOM_MODES=ON \
		-DOPUS_FLOAT_APPROX=ON \
		-DOPUS_INSTALL_PKG_CONFIG_MODULE=OFF \
		-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=OFF \
		"${GENERATOR_PARAMS[@]}"
	cmake --build . --target install --config Release
	popd >/dev/null
}

cmake_toolchain()
{
	case "$1" in
		"android_armv7")
			echo "$SCRIPT_DIR/polly/android-ndk-r16b-api-21-armeabi-v7a-neon-clang-libcxx.cmake"
			;;
		"android_arm64")
			echo "$SCRIPT_DIR/polly/android-ndk-r16b-api-21-arm64-v8a-neon-clang-libcxx.cmake"
			;;
		"android_x86")
			echo "$SCRIPT_DIR/polly/android-ndk-r16b-api-21-x86-clang-libcxx.cmake"
			;;
		"android_x64")
			echo "$SCRIPT_DIR/polly/android-ndk-r16b-api-21-x86-64-clang-libcxx.cmake"
			;;
		"ios")
			echo "$SCRIPT_DIR/polly/ios-nocodesign.cmake"
			;;
		"macos")
			echo "$SCRIPT_DIR/polly/xcode.cmake"
			;;
		"win64")
			echo "$SCRIPT_DIR/polly/vs-14-2015-win64.cmake"
			;;
		*)
			echo "SCRIPT_DIR/polly/$1"
			;;
	esac
}

cmake_generator_params()
{
	case "$1" in
		"ios")
			echo '-G Xcode -DIOS_DEPLOYMENT_SDK_VERSION=10.0'
			;;
		"macos")
			echo '-G Xcode'
			;;
		"win64")
			echo '-G "Visual Studio 14 2015"'
			;;
	esac
}

cmake_build_type()
{
	case "$1" in
		"static")
			echo 0
			;;
		"shared")
			echo 1
			;;
		*)
			echo -1
			;;
	esac
}

__main__ "$@"
exit $?
