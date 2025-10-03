#!/bin/sh
# ====================================================================
# The MIT License (MIT)
#
# Copyright (c) 2017 Feral Interactive Limited
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ====================================================================
# Generic Feral Launcher script
# Version 2.1.1

# If you have useful edits made for unsupported distros then please
# let us know at <linuxscriptsuggestions@feralinteractive.com>

# Extra note: Steam's STEAM_RUNTIME_PREFER_HOST_LIBRARIES can now be
# used to control which libraries it'll use
# See http://store.steampowered.com/news/26953/
# ====================================================================

# 'Magic' to get the game root
GAMEROOT="$(sh -c "cd \"${0%/*}\" && echo \"\$PWD\"")"
echo "GAMEROOT=$GAMEROOT"
# Pull in game specific variables
# shellcheck source=config/game-settings.sh
. "${GAMEROOT}/config/game-settings.sh"

# The game's preferences directory
GAMEPREFS="$HOME/.local/share/feral-interactive/${FERAL_GAME_NAME_FULL}"

# Check for arguments
# Note: some of these can be set at a system level to override for
# all Feral games
while [ $# -gt 0 ]; do
	arg=$1
	case ${arg} in
		--fresh-prefs)   FERAL_FRESH_PREFERENCES=1  && shift ;;
		--system-asound) FERAL_SYSTEM_ASOUND=1      && shift ;;
		--version)       FERAL_GET_VERSION=1        && shift ;;
		*) break ;;
	esac
done

# ====================================================================
# Options

# Automatically backup old preferences and start fresh on launch
if [ "${FERAL_FRESH_PREFERENCES}" = 1 ]; then
	mv "${GAMEPREFS}" "${GAMEPREFS}-$(date +%Y%m%d%H%M%S).bak"
fi

# Show a version panel on start
if [ "${FERAL_GET_VERSION}" = 1 ]; then
	unset LD_PRELOAD
	unset LD_LIBRARY_PATH
	if [ -x /usr/bin/zenity ]; then
		/usr/bin/zenity --text-info --title "${FERAL_GAME_NAME_FULL} - Version Information" --filename "${GAMEROOT}/share/FeralInfo.json"
	else
		xterm -T "${FERAL_GAME_NAME_FULL} - Version Information" -e "cat '${GAMEROOT}/share/FeralInfo.json'; echo -n 'Press ENTER to continue: '; read input"
	fi
	exit
fi

# ====================================================================
# Our games are compiled targeting the steam runtime and are not
# expected to work perfectly when run outside of it
# However on some distributions (Arch Linux/openSUSE etc.) users have
# had better luck using their own libs
# Remove the line below if testing that
# shellcheck source=config/steam-check.sh
. "${GAMEROOT}/config/steam-check.sh"

# ====================================================================
# Set the steam appid if not set
if [ "${SteamAppId}" != "${FERAL_GAME_STEAMID}" ]; then
	SteamAppId="${FERAL_GAME_STEAMID}"
	GameAppId="${FERAL_GAME_STEAMID}"
	export SteamAppId
	export GameAppId
fi

# ====================================================================
# Enviroment Modifiers

# Store the current LD_PRELOAD
SYSTEM_LD_PRELOAD="${LD_PRELOAD}"
LD_PRELOAD_ADDITIONS="/opt/shogun2-fix/libc_mprotect.so:/opt/shogun2-fix/libc_dlopen_mode.so"

# Unset LD_PRELOAD temporarily
# This avoids a chunk of confusing 32/64 errors from the steam overlay
# It also allows us to call the system openssl and curl here
# If your distribution needed an LD_PRELOAD addition then it should be
# fine to comment this out
unset LD_PRELOAD

# LC_ALL has caused users many issues in the past and generally is just
# used for debugging
# Uncomment this line if LC_ALL was needed (sometimes on openSUSE)
unset LC_ALL

# Try and set up SSL paths for all distros, due to steam runtime bug #52
# The value is used by our version of libcurl
# Users on unsupported distros might want to check if this is correct
HAS_CURL="$(sh -c "command -v curl-config")"
if [ -n "${HAS_CURL}" ]; then
	SSL_CERT_FILE="$(curl-config --ca)"
	export SSL_CERT_FILE
else
	# Otherwise try with guess work
	if [ -e /etc/ssl/certs/ca-certificates.crt ]; then
		SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
		export SSL_CERT_FILE
	elif [ -e /etc/pki/tls/certs/ca-bundle.crt ]; then
		SSL_CERT_FILE="/etc/pki/tls/certs/ca-bundle.crt"
		export SSL_CERT_FILE
	elif [ -e /var/lib/ca-certificates/ca-bundle.pem ]; then
		SSL_CERT_FILE="/var/lib/ca-certificates/ca-bundle.pem"
		export SSL_CERT_FILE
	fi
fi
HAS_OPENSSL="$(sh -c "command -v openssl")"
if [ -n "${HAS_OPENSSL}" ]; then
	SSL_CERT_DIR="$(sh -c "openssl version -d | sed -E 's/.*\\\"(.*)\\\"/\1/'")/certs"
	export SSL_CERT_DIR
fi

# Move the driver shader cache to our preferences
if [ -z "$__GL_SHADER_DISK_CACHE_PATH" ]; then
	export __GL_SHADER_DISK_CACHE_PATH="${GAMEPREFS}/driver-gl-shader-cache"
	# Avoid steam runtime libraries for mkdir
	OLD_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
	unset LD_LIBRARY_PATH
	mkdir -p "${__GL_SHADER_DISK_CACHE_PATH}"
	export LD_LIBRARY_PATH="${OLD_LD_LIBRARY_PATH}"
fi

# Brute force fix for some small thread sizes in external libraries
if [ -e "${GAMEROOT}/${FERAL_LIB_PATH}/libminimum_thread_stack_size_wrapper.so" ]; then
	LD_PRELOAD_ADDITIONS="../${FERAL_LIB_PATH}/libminimum_thread_stack_size_wrapper.so:${LD_PRELOAD_ADDITIONS}"
fi

# Use the system asound if requested
# This can help with sound issues on some distros including Arch Linux
# Now most likely only needed if STEAM_RUNTIME_PREFER_HOST_LIBRARIES is set to 0
if [ "${FERAL_SYSTEM_ASOUND}" = 1 ]; then
	LIBASOUND_DYLIB="libasound.so.2"
	if [ -e "/usr/lib/${FERAL_ARCH_FULL}-linux-gnu/${LIBASOUND_DYLIB}" ]; then
		LIBASOUND_LIBDIR="/usr/lib/${FERAL_ARCH_FULL}-linux-gnu"
	elif [ -e "/usr/lib${FERAL_ARCH_SHORT}/${LIBASOUND_DYLIB}" ]; then
		LIBASOUND_LIBDIR="/usr/lib${FERAL_ARCH_SHORT}"
	elif [ -e "/usr/lib/${LIBASOUND_DYLIB}" ]; then
		LIBASOUND_LIBDIR="/usr/lib"
	fi
	LD_PRELOAD_ADDITIONS="${LIBASOUND_LIBDIR}/${LIBASOUND_DYLIB}:${LD_PRELOAD_ADDITIONS}"
fi

# Sometimes games may need an extra set of variables
# Let's pull those in
# shellcheck source=config/extra-environment.sh
. "${GAMEROOT}/config/extra-environment.sh"

# Add our additionals and the old preload back
LD_PRELOAD="${LD_PRELOAD_ADDITIONS}:${SYSTEM_LD_PRELOAD}"
export LD_PRELOAD

export LD_LIBRARY_PATH="${GAMEROOT}/${FERAL_LIB_PATH}:${LD_LIBRARY_PATH}"

# ====================================================================
# Try and detect some common problems and show useful messages
# First check the dynamic linker
GAME_LDD_LOGFILE=/tmp/${FERAL_GAME_NAME}_ldd_log
if command -v ldd > /dev/null; then
	ldd "${GAMEROOT}/bin/${FERAL_GAME_NAME}" > "${GAME_LDD_LOGFILE}.txt"
	grep "not found" "${GAME_LDD_LOGFILE}.txt" > "${GAME_LDD_LOGFILE}_missing.txt"
	if [ -s "${GAME_LDD_LOGFILE}_missing.txt" ]; then
		echo "=== ERROR - You're missing vital libraries to run ${FERAL_GAME_NAME_FULL}"
		echo "=== Either use the steam runtime or install these using your package manager"
		cat "${GAME_LDD_LOGFILE}_missing.txt" && echo "==="
		rm "${GAME_LDD_LOGFILE}_missing.txt"
	fi
	rm "${GAME_LDD_LOGFILE}.txt"
fi

# ====================================================================
# Run the game
cd "${GAMEROOT}/bin" && ${GAME_LAUNCH_PREFIX} "${GAMEROOT}/bin/${FERAL_GAME_NAME}" "$@"
RESULT=$?

# ====================================================================
exit "${RESULT}"
