#!/bin/bash
#
# webdriver.sh - bash script for managing Nvidia's web drivers
# Copyright © 2017-2018 vulgo
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

SCRIPT_VERSION="1.3.0"
grep="/usr/bin/grep"
shopt -s nullglob extglob
BASENAME=$(/usr/bin/basename "$0")
DIRNAME=$(/usr/bin/dirname "$0")
RAW_ARGS=("$@")
if ! LOCAL_BUILD=$(/usr/sbin/sysctl -n kern.osversion); then
	printf 'sysctl error'; exit $?; fi
LOCAL_MAJOR="${LOCAL_BUILD:0:2}"
if (( LOCAL_MAJOR != 17 )); then
	printf 'Unsupported macOS version'; exit 1; fi
if [[ ! -f "${DIRNAME}/.portable" ]]; then
	LIBEXEC="/etc/webdriver.sh/"
	if /bin/ls -la "$0" | $grep -qi cellar; then
		HOST_PREFIX=$(brew --prefix 2> /dev/null)
	else
		HOST_PREFIX=/usr/local; LIBEXEC="/libexec/webdriver.sh/"
	fi
else
	HOST_PREFIX="${DIRNAME}"; LIBEXEC="/"
fi
	
# SIP
declare KEXT_ALLOWED=false FS_ALLOWED=false
$grep -qiE -e "status: disabled|signing: disabled" <(/usr/bin/csrutil status) && KEXT_ALLOWED=true
/usr/bin/touch /System 2> /dev/null && FS_ALLOWED=true

test -t 0 && declare R='\e[0m' B='\e[1m' U='\e[4m'
DRIVERS_DIR_HINT="NVWebDrivers.pkg"
STARTUP_KEXT="/Library/Extensions/NVDAStartupWeb.kext"
EGPU_KEXT="/Library/Extensions/NVDAEGPUSupport.kext"
ERR_PLIST_READ="Couldn't read a required value from a property list"
ERR_PLIST_WRITE="Couldn't set a required value in a property list"
SET_NVRAM="/usr/sbin/nvram nvda_drv=1%00"
UNSET_NVRAM="/usr/sbin/nvram -d nvda_drv"
declare CHANGES_MADE=false RESTART_REQUIRED=false REINSTALL_MESSAGE=false
declare -i EXIT_ERROR=0 COMMAND_COUNT=0 DONT_INVALIDATE_KEXTS=0
declare -i CLOVER_AUTO_PATCH=1 CLOVER_PATCH=0 CLOVER_DIR=0
declare OPT_REINSTALL=false OPT_SYSTEM=false OPT_ALL=false OPT_YES=false

if [[ $BASENAME =~ "swebdriver" ]]; then
	[[ $1 != "-u" ]] && exit 1
	[[ -z $2 ]] && exit 1
	set -- "-u" "$2"
	OPT_SYSTEM=true
	OPT_YES=true
else
	SETTINGS_PATH="$HOST_PREFIX/etc/webdriver.sh/settings.conf"
	set --
	for arg in "${RAW_ARGS[@]}"
	do
		case "$arg" in
		@(|-|--)show-settings)
			/usr/bin/open -R "$SETTINGS_PATH"
			exit $?;;
		@(|-|--)help)
			set -- "$@" "-h";;
		@(|-|--)list)
			set -- "$@" "-l";;
		@(|-|--)url)
			set -- "$@" "-u";;
		@(|-|--)remove)
			set -- "$@" "-r";;
		@(|-|--)uninstall)
			set -- "$@" "-r";;
		@(|-|--)version)
			set -- "$@" "-v";;
		*)
			set -- "$@" "$arg";;
		esac
	done
fi

function usage() {
	local -i status=$1
	[[ $DIRNAME == "." ]] && BASENAME="./${BASENAME}"
	printf 'Usage: %s [-f] [-l|-u|-r|-m|FILE]\n' "$BASENAME"	
	printf '   --list    or  -l          choose which driver to install from a list\n'
	printf '   --url     or  -u URL      download package from URL and install drivers\n'
	printf '   --remove  or  -r          uninstall NVIDIA web drivers\n'
	printf "                 -m [BUILD]  apply Info.plist patch for NVDARequiredOS"'\n'
	printf '                 -f          continue when same version already installed\n'
	exit $(( status ))
}

function version() {
	printf 'webdriver.sh %s Copyright © 2017-2018 vulgo\n' "$SCRIPT_VERSION"
	printf 'This is free software: you are free to change and redistribute it.\n'
	printf 'There is NO WARRANTY, to the extent permitted by law.\n'
	printf 'See the GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>\n'
	exit 0
}

while getopts ":hvlu:rm:fa!:#:Yc" OPTION; do
	case $OPTION in
	"c")
		printf 'Option -c has been removed\n';;
	"h")
		usage;;
	"v")
		version;;
	"l")
		COMMAND="CMD_LIST"
		OPT_REINSTALL=true
		COMMAND_COUNT+=1;;
	"u")
		COMMAND="CMD_USER_URL"
		REMOTE_URL="$OPTARG"
		COMMAND_COUNT+=1;;
	"r")
		COMMAND="CMD_UNINSTALL"
		COMMAND_COUNT+=1;;
	"m")
		COMMAND="CMD_REQUIRED_OS"
		OPT_REQUIRED_OS="$OPTARG"
		COMMAND_COUNT+=1;;
	"f")
		OPT_REINSTALL=true;;
	"a")
		OPT_ALL=true;;
	"!")
		# shellcheck disable=SC2034
		CONFIG_ARGS="$OPTARG";;
	"#")
		REMOTE_CHECKSUM="$OPTARG";;
	"Y")
		OPT_YES=true;;
	"?")
		printf 'Invalid option: -%s\n' "$OPTARG"
		usage 1;;
	":")
		if [[ $OPTARG == "m" ]]; then
			OPT_REQUIRED_OS="$LOCAL_BUILD"
			COMMAND="CMD_REQUIRED_OS"
			COMMAND_COUNT+=1
		else
			printf 'Missing parameter for -%s\n' "$OPTARG"
			usage 1
		fi;;
	esac
	if (( COMMAND_COUNT > 1)); then
		printf 'Too many options\n'
		usage 1
	fi
done

if (( COMMAND_COUNT == 0 )); then
	shift $(( OPTIND - 1 ))
	while (( $# > 0)); do
		if [[ -f "$1" ]]; then
			COMMAND="CMD_FILE"
			OPT_FILEPATH="$1"
			break
		fi
	shift
	done
fi

[[ $(/usr/bin/id -u) != "0" ]] && exec /usr/bin/sudo -u root "$0" "${RAW_ARGS[@]}"
uuidgen="/usr/bin/uuidgen"
TMP_DIR=$(/usr/bin/mktemp -dt webdriver)
# shellcheck disable=SC2064
trap "rm -rf $TMP_DIR; stty echo echok; exit" SIGINT SIGTERM SIGHUP
UPDATES_PLIST="${TMP_DIR}/$($uuidgen)"
INSTALLER_PKG="${TMP_DIR}/$($uuidgen)"
EXTRACTED_PKG_DIR="${TMP_DIR}/$($uuidgen)"
DRIVERS_PKG="${TMP_DIR}/com.nvidia.web-driver.pkg"
DRIVERS_ROOT="${TMP_DIR}/$($uuidgen)"

function s() {
	# $@: args... 
	"$@" > /dev/null 2>&1
	return $?
}

function e() {
	# $1: message, $2: exit_code
	s rm -rf "$TMP_DIR"
	if [[ -z $2 ]]; then
		printf '%bError%b: %s\n' "$U" "$R" "$1"
	else
		printf '%bError%b: %s (%s)\n' "$U" "$R" "$1" "$2"
	fi
	$CHANGES_MADE && $UNSET_NVRAM
	! $CHANGES_MADE && printf 'No changes were made\n'
	exit 1
}

function exit_quietly() {
	s rm -rf "$TMP_DIR"
	exit $EXIT_ERROR
}

function exit_after_changes() {
	MSG="$1"
	[[ -z $1 ]] && MSG="Complete."
	s rm -rf "$TMP_DIR"
	printf '%s' "$MSG"
	[[ $EXIT_ERROR -eq 0 ]] && $RESTART_REQUIRED && printf ' You should reboot now.'
	printf '\n'
	exit $EXIT_ERROR
}

function warning() {
	# $1: message
	printf '%bWarning%b: %s\n' "$U" "$R" "$1" 
}

function etc() {
	# $1: path to script
	# shellcheck source=/dev/null
	[[ -f "${HOST_PREFIX}/etc/webdriver.sh/${1}" ]] && source "${HOST_PREFIX}/etc/webdriver.sh/${1}"
}

function libexec() {
	# $1: path to symlink
	if [[ -f "${HOST_PREFIX}${LIBEXEC}${1}" ]]; then
		"${HOST_PREFIX}${LIBEXEC}${1}"
		return $?
	else
		local MESSAGE="Executable not found: ${HOST_PREFIX}${LIBEXEC}${1}"
		warning "$MESSAGE"
		return 1
	fi
}

function scpt() {
	# $1: path to applescript
	[[ -f "${HOST_PREFIX}/etc/webdriver.sh/${1}" ]] \
		&& /usr/bin/osascript  "${HOST_PREFIX}/etc/webdriver.sh/${1}" > /dev/null 2>&1
}

function uninstall_drivers() {
	local REMOVE_LIST=(/Library/Extensions/GeForce* \
		/Library/Extensions/NVDA* \
		/System/Library/Extensions/GeForce*Web* \
		/System/Library/Extensions/NVDA*Web*)
	REMOVE_LIST=("${REMOVE_LIST[@]/$EGPU_KEXT}")
	# shellcheck disable=SC2086
	s rm -rf "${REMOVE_LIST[@]}"
	s pkgutil --forget com.nvidia.web-driver
	etc "uninstall.conf"
}

function caches_error() {
	# $1: warning message
	warning "$1"
	EXIT_ERROR=1
	RESTART_REQUIRED=false
}

function update_caches() {
	if $OPT_SYSTEM; then
		warning "Caches are not being updated"
		return 0
	fi
	local PK="CREATED PRELINKED KERNEL"
	local ERR_PK="There was a problem creating the prelinked kernel"
	local SLE="CACHES UPDATED FOR /SYSTEM/LIBRARY/EXTENSIONS"
	local ERR_SLE="There was a problem updating directory caches for /S/L/E"
	local LE="CACHES UPDATED FOR /LIBRARY/EXTENSIONS"
	local ERR_LE="There was a problem updating directory caches for /L/E"
	local RESULT
	printf '%bUpdating caches...%b\n' "$B" "$R"
	RESULT=$(/usr/sbin/kextcache -v 2 -i / 2>&1)
	$grep -qie "$PK" <<< "$RESULT" || caches_error "$ERR_PK"
	$grep -qie "$SLE" <<< "$RESULT" || caches_error "$ERR_SLE"
	$grep -qie "$LE" <<< "$RESULT" || caches_error "$ERR_LE"
	(( EXIT_ERROR != 0 )) && printf '\nTo try again use:\n%bsudo kextcache -i /%b\n\n' "$B" "$R"	 
}

function ask() {
	# $1: prompt message
	local ASK
	printf '%b%s%b' "$B" "$1" "$R"
	read -n 1 -srp " [y/N]" ASK
	printf '\n'
	if [[ $ASK == "y" || $ASK == "Y" ]]; then
		return 0
	else
		return 1
	fi
}

function plistb() {
	# $1: plistbuddy command, $2: property list
	local RESULT
	[[ ! -f "$2" ]] && return 1
	! RESULT=$(/usr/libexec/PlistBuddy -c "$1" "$2" 2> /dev/null) && return 1
	[[ $RESULT ]] && printf "%s" "$RESULT"
	return 0
}

function set_required_os() {
	# $1: target macos version
	KEXTS=("${STARTUP_KEXT}" "${EGPU_KEXT}")
	local NVDA_REQUIRED_OS TARGET_BUILD="$1" KEY=":IOKitPersonalities:NVDAStartup:NVDARequiredOS"
	for KEXT in "${KEXTS[@]}"; do
		if [[ -f "${KEXT}/Contents/Info.plist" ]]; then
			NVDA_REQUIRED_OS=$(plistb "Print ${KEY}" "${KEXT}/Contents/Info.plist") || e "$ERR_PLIST_READ"
			if [[ $NVDA_REQUIRED_OS == "$TARGET_BUILD" ]]; then
				printf '%s: Already set to %b%s%b\n' "$(basename "$KEXT")"  "$B" "$TARGET_BUILD" "$R"
		        else
				printf '%s: %s -> %b%s%b\n' "$(basename "$KEXT")" "$NVDA_REQUIRED_OS" "$B" "$TARGET_BUILD" "$R"
				CHANGES_MADE=true
				plistb "Set ${KEY} ${TARGET_BUILD}" "${KEXT}/Contents/Info.plist" || e "$ERR_PLIST_WRITE"
			fi
		fi
	done
}

function check_required_os() {
	{ $OPT_YES || (( DONT_INVALIDATE_KEXTS == 1 )) || (( CLOVER_PATCH == 1 )); } && return 0
	[[ ! -f "${STARTUP_KEXT}/Contents/Info.plist" ]] && return 0
	local RESULT KEY=":IOKitPersonalities:NVDAStartup:NVDARequiredOS"
	RESULT=$(plistb "Print $KEY" "${STARTUP_KEXT}/Contents/Info.plist") || e "$ERR_PLIST_READ"
	[[ $RESULT == "$LOCAL_BUILD" ]] && return 0
	ask "Modify installed driver for the current macOS version?" || return 0
	set_required_os "$LOCAL_BUILD"
	RESTART_REQUIRED=true
	$KEXT_ALLOWED || warning "Disable SIP, run 'kextcache -i /' to allow modified drivers to load"
	return 1
}

function sql_add_kext() {
	# $1: bundle id
	SQL+="insert or replace into kext_policy (team_id, bundle_id, allowed, developer_name, flags) "
	SQL+="values (\"6KR3T733EC\",\"${1}\",1,\"NVIDIA Corporation\",1); "
}

function match_build() {
	# $1: local, $2: remote
	local -i LOCAL=$1 REMOTE=$2
	[[ $REMOTE -eq $(( LOCAL + 1 )) ]] && return 0
	[[ $REMOTE -ge 17 && $REMOTE -eq $(( LOCAL - 1 )) ]] && return 0
	return 1
}

# Load settings

etc "settings.conf"

# Clover patch

if { kextstat | $grep -qiE -e "fakesmc"; } && (( CLOVER_AUTO_PATCH == 1)); then
	BOOT_LOG=$(/usr/sbin/ioreg -p IODeviceTree -c IOService -k boot-log -d 1 -r | $grep boot-log \
		| /usr/bin/awk -v FS="(<|>)" '{print $2}' | /usr/bin/xxd -r -p)
	$grep -qiE -e 'selfdirpath.*\\efi\\clover' <<< "$BOOT_LOG" && CLOVER_DIR=1
	if $grep -qiE -e "nvdastartupweb.*allowed" <<< "$BOOT_LOG"; then
		CLOVER_PATCH=1
	elif $grep -qiE -e "nvdastartupweb.*disabled.*user" <<< "$BOOT_LOG"; then
		CLOVER_PATCH=-1
	fi
	(( CLOVER_DIR == 1 && CLOVER_PATCH != 1 && CLOVER_PATCH != -1 )) && libexec "clover-patcher" && CLOVER_PATCH=1
	if (( CLOVER_DIR == 1 && CLOVER_PATCH == -1 )) && ! $OPT_YES; then
		if ask "Enable Clover patch?"; then
			libexec "clover-patcher" && CLOVER_PATCH=1
		else
			CLOVER_PATCH=0
		fi
	fi
fi

# COMMAND CMD_REQUIRED_OS

if [[ $COMMAND == "CMD_REQUIRED_OS" ]]; then
	if [[ ! -f "${STARTUP_KEXT}/Contents/Info.plist" ]]; then
		printf 'NVIDIA driver not found\n'
		$UNSET_NVRAM
		exit_quietly
	else
		if (( CLOVER_PATCH == 1 )); then
			warning "NVDAStartupWeb is already being patched by Clover"
			ask 'Continue?' || exit_quietly
		fi
		set_required_os "$OPT_REQUIRED_OS"
	fi
	if $CHANGES_MADE; then
		update_caches
		$SET_NVRAM
		exit_after_changes
	else
		exit_quietly
	fi
fi

# COMMAND CMD_UNINSTALL

if [[ $COMMAND == "CMD_UNINSTALL" ]]; then
	ask "Uninstall NVIDIA web drivers?" || exit_quietly
	printf '%bRemoving files...%b\n' "$B" "$R"
	CHANGES_MADE=true
	RESTART_REQUIRED=true
	uninstall_drivers
	update_caches
	$UNSET_NVRAM
	exit_after_changes "Uninstall complete."
fi

# UPDATER/INSTALLER

if [[ $COMMAND == "CMD_USER_URL" ]]; then
	# Invoked with -u option, proceed to installation
	printf 'URL: %s\n' "$REMOTE_URL"
elif [[ $COMMAND == "CMD_FILE" ]]; then
	# Parsed file path, proceed to installation
	printf 'File: %s\n' "$OPT_FILEPATH"
else
	# No URL / filepath
	if [[ $COMMAND == "CMD_LIST" ]]; then
		declare -a LIST_URLS LIST_VERSIONS LIST_CHECKSUMS LIST_BUILDS
		declare -i VERSION_MAX_WIDTH
	fi
	# Get installed version
	INFO_STRING=$(plistb "Print :CFBundleGetInfoString" "/Library/Extensions/GeForceWeb.kext/Contents/Info.plist")
	[[ $INFO_STRING ]] && INSTALLED_VERSION="${INFO_STRING##* }"
	# Get updates file
	printf '%bChecking for updates...%b\n' "$B" "$R"
	/usr/bin/curl -s --connect-timeout 15 -m 45 -o "$UPDATES_PLIST" "https://gfestage.nvidia.com/mac-update" \
		|| e "Couldn't get updates data from NVIDIA" $?
	# shellcheck disable=SC2155
	declare -i c=$($grep -c "<dict>" "$UPDATES_PLIST")
	for (( i = 0; i < c - 1; i += 1 )); do
		unset -v "REMOTE_BUILD" "REMOTE_MAJOR" "REMOTE_URL" "REMOTE_VERSION" "REMOTE_CHECKSUM"
		! REMOTE_BUILD=$(plistb "Print :updates:${i}:OS" "$UPDATES_PLIST") && break			
		if [[ $REMOTE_BUILD == "$LOCAL_BUILD" || $COMMAND == "CMD_LIST" ]]; then
			REMOTE_MAJOR=${REMOTE_BUILD:0:2}
			REMOTE_URL=$(plistb "Print :updates:${i}:downloadURL" "$UPDATES_PLIST")
			REMOTE_VERSION=$(plistb "Print :updates:${i}:version" "$UPDATES_PLIST")
			REMOTE_CHECKSUM=$(plistb "Print :updates:${i}:checksum" "$UPDATES_PLIST")
			if [[ $COMMAND == "CMD_LIST" ]]; then
				if [[ $LOCAL_MAJOR == "$REMOTE_MAJOR" ]] \
				|| ( $OPT_ALL && match_build "$LOCAL_MAJOR" "$REMOTE_MAJOR" ); then
					LIST_URLS+=("$REMOTE_URL")
					LIST_VERSIONS+=("$REMOTE_VERSION")
					LIST_CHECKSUMS+=("$REMOTE_CHECKSUM")
					LIST_BUILDS+=("$REMOTE_BUILD")
					[[ ${#REMOTE_VERSION} -gt $VERSION_MAX_WIDTH ]] && VERSION_MAX_WIDTH=${#REMOTE_VERSION}
				fi
				(( ${#LIST_VERSIONS[@]} > 47 )) && break
				continue
			fi	
			break
		fi
	done;
	if [[ $COMMAND == "CMD_LIST" ]]; then
		MACOS_PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion)"
		while true; do
			printf '%bCurrent driver:%b ' "$B" "$R"
			if [[ $INSTALLED_VERSION ]]; then
				printf '%s\n' "$INSTALLED_VERSION"
			else
				printf 'Not installed\n'
			fi
			printf '%bRunning on:%b macOS %s (%s)\n\n' "$B" "$R" "$MACOS_PRODUCT_VERSION" "$LOCAL_BUILD"
			count=${#LIST_VERSIONS[@]}
			FORMAT_COMMAND="/usr/bin/tee"
			tl=$(/usr/bin/tput lines)
			[[ $count -gt $(( tl - 5 )) || $count -gt 15 ]] && FORMAT_COMMAND="/usr/bin/column"
			VERSION_FORMAT_STRING="%-${VERSION_MAX_WIDTH}s"
			for (( i = 0; i < count; i += 1 )); do
				ROW="$(printf '%6s.' $(( i + 1 )))"
				ROW+="  "
				# shellcheck disable=SC2059
				ROW+="$(printf "$VERSION_FORMAT_STRING" "${LIST_VERSIONS[$i]}")"
				ROW+="  "
				ROW+="${LIST_BUILDS[$i]}"
				printf '%s\n' "$ROW"
			done | $FORMAT_COMMAND
			printf '\n'
			printf '%bWhat now?%b [1-%s] : ' "$B" "$R" "$count"
			read -r int
			[[ -z $int ]] && exit_quietly
			if [[ $int =~ ^[0-9] ]] && (( int >= 1 )) && (( int <= count )); then
				(( int -= 1 ))
				REMOTE_URL=${LIST_URLS[$int]}
				REMOTE_VERSION=${LIST_VERSIONS[$int]}
				REMOTE_BUILD=${LIST_BUILDS[$int]}
				REMOTE_CHECKSUM=${LIST_CHECKSUMS[$int]}
				break
			fi
			printf '\nTry again...\n\n'
			/usr/bin/tput bel
		done
	fi
	# Determine next action
	if [[ -z $REMOTE_URL || -z $REMOTE_VERSION ]]; then
		# No driver available, or error during check, exit
		printf 'No driver available for %s\n' "$LOCAL_BUILD"
		if ! check_required_os; then
			update_caches
			$SET_NVRAM
			exit_after_changes
		fi
		exit_quietly
	elif [[ $REMOTE_VERSION == "$INSTALLED_VERSION" ]]; then
		# Chosen version already installed
		if [[ -f ${STARTUP_KEXT}/Contents/Info.plist ]]; then
			REQUIRED_OS_KEY=":IOKitPersonalities:NVDAStartup:NVDARequiredOS"
			LOCAL_REQUIRED_OS=$(plistb "Print $REQUIRED_OS_KEY" "${STARTUP_KEXT}/Contents/Info.plist"); fi
		if [[ $LOCAL_REQUIRED_OS ]]; then
			printf '%s for %s already installed\n' "$REMOTE_VERSION" "$LOCAL_REQUIRED_OS"
		else
			printf '%s already installed\n' "$REMOTE_VERSION"
			OPT_REINSTALL=true
		fi
		if ! s codesign -v "$STARTUP_KEXT"; then
			printf 'Invalid signature: '
			$KEXT_ALLOWED && printf 'Allowed\n'
			! $KEXT_ALLOWED && printf 'Not allowed\n'
		fi		
		if ! check_required_os; then
			update_caches
			$SET_NVRAM
			exit_after_changes
		fi
		if $OPT_REINSTALL; then
			REINSTALL_MESSAGE=true
		else
			exit_quietly
		fi
	else
		if [[ $COMMAND != "CMD_LIST" ]]; then
			# Found an update, proceed to installation
			printf 'Web driver %s available...\n' "$REMOTE_VERSION"
		else
			# Chosen from a list
			printf 'Selected: %s for %s\n' "$REMOTE_VERSION" "$REMOTE_BUILD"
		fi
	fi
fi

# Prompt install y/n

if ! $OPT_YES; then
	if $REINSTALL_MESSAGE; then
		ask "Re-install?" || exit_quietly
	else
		ask "Install?" || exit_quietly
	fi
fi

if [[ $COMMAND != "CMD_FILE" ]]; then
	# Check URL
	REMOTE_HOST=$(printf '%s' "$REMOTE_URL" | /usr/bin/awk -F/ '{print $3}')
	if ! s /usr/bin/host "$REMOTE_HOST"; then
		[[ $COMMAND == "CMD_USER_URL" ]] && e "Unable to resolve host, check your URL"
		REMOTE_URL="https://images.nvidia.com/mac/pkg/"
		REMOTE_URL+="${REMOTE_VERSION%%.*}"
		REMOTE_URL+="/WebDriver-${REMOTE_VERSION}.pkg"
	fi
	HEADERS=$(/usr/bin/curl -I "$REMOTE_URL" 2>&1) || e "Failed to download HTTP headers"
	$grep -qe "octet-stream" <<< "$HEADERS" || warning "Unexpected HTTP content type"
	[[ $COMMAND != "CMD_USER_URL" ]] && printf 'URL: %s\n' "$REMOTE_URL"

	# Download
	printf '%bDownloading package...%b\n' "$B" "$R"
	/usr/bin/curl --connect-timeout 15 -# -o "$INSTALLER_PKG" "$REMOTE_URL" || e "Failed to download package" $?

	# Checksum
	LOCAL_CHECKSUM=$(/usr/bin/shasum -a 512 "$INSTALLER_PKG" 2> /dev/null | /usr/bin/awk '{print $1}')
	if [[ $REMOTE_CHECKSUM ]]; then
		if [[ $LOCAL_CHECKSUM == "$REMOTE_CHECKSUM" ]]; then
			printf 'SHA512: Verified\n'
		else
			e "SHA512 verification failed"
		fi
	else
		printf 'SHA512: %s\n' "$LOCAL_CHECKSUM"
	fi
else
	/bin/cp "$OPT_FILEPATH" "$INSTALLER_PKG"
fi

# Unflatten

printf '%bExtracting...%b\n' "$B" "$R"
/usr/sbin/pkgutil --expand "$INSTALLER_PKG" "$EXTRACTED_PKG_DIR" || e "Failed to extract package" $?
DIRS=("$EXTRACTED_PKG_DIR"/*"$DRIVERS_DIR_HINT")
if [[ ${#DIRS[@]} -eq 1 ]] && [[ -d ${DIRS[0]} ]]; then
        DRIVERS_COMPONENT_DIR=${DIRS[0]}
else
        e "Failed to find pkgutil output directory"
fi

# Extract drivers

mkdir "$DRIVERS_ROOT"
/usr/bin/gunzip -dc < "${DRIVERS_COMPONENT_DIR}/Payload" > "${DRIVERS_ROOT}/tmp.cpio" \
	|| e "Failed to extract package" $?
cd "$DRIVERS_ROOT" || e "Failed to find drivers root directory" $?
/usr/bin/cpio -i < "${DRIVERS_ROOT}/tmp.cpio" || e "Failed to extract package" $?
s rm -f "${DRIVERS_ROOT}/tmp.cpio"
if [[ ! -d ${DRIVERS_ROOT}/Library/Extensions || ! -d ${DRIVERS_ROOT}/System/Library/Extensions ]]; then
	e "Unexpected directory structure after extraction"
fi

# User-approved kernel extension loading

cd "$DRIVERS_ROOT" || e "Failed to find drivers root directory" $?
KEXT_INFO_PLISTS=(./Library/Extensions/*.kext/Contents/Info.plist)
declare -a BUNDLES APPROVED_BUNDLES
for PLIST in "${KEXT_INFO_PLISTS[@]}"; do
	BUNDLE_ID=$(plistb "Print :CFBundleIdentifier" "$PLIST")
	[[ $BUNDLE_ID ]] && BUNDLES+=("$BUNDLE_ID")
done
if $FS_ALLOWED; then
	# Approve kexts
	printf '%bApproving extensions...%b\n' "$B" "$R"
	for BUNDLE_ID in "${BUNDLES[@]}"; do
		sql_add_kext "$BUNDLE_ID"
	done
	sql_add_kext "com.nvidia.CUDA"
	/usr/bin/sqlite3 /private/var/db/SystemPolicyConfiguration/KextPolicy <<< "$SQL" \
		|| warning "sqlite3 exit code $?"
else
	# Get unapproved bundle IDs
	printf '%bExamining extensions...%b\n' "$B" "$R"
	QUERY="select bundle_id from kext_policy where team_id=\"6KR3T733EC\" and (flags=1 or flags=8)"
	while IFS= read -r LINE; do
		APPROVED_BUNDLES+=("$LINE")
	done < <(/usr/bin/sqlite3 /private/var/db/SystemPolicyConfiguration/KextPolicy "$QUERY" 2> /dev/null)
	for MATCH in "${APPROVED_BUNDLES[@]}"; do
		for index in "${!BUNDLES[@]}"; do
			if [[ ${BUNDLES[index]} == "$MATCH" ]]; then
				unset "BUNDLES[index]";
			fi;
		done;
	done
	UNAPPROVED_BUNDLES=$(printf "%s" "${BUNDLES[@]}")
fi
		
# Install

uninstall_drivers
declare CHANGES_MADE=true NEEDS_KEXTCACHE=false RESTART_REQUIRED=true
if ! $FS_ALLOWED; then
	s /usr/bin/pkgbuild --identifier com.nvidia.web-driver --root "$DRIVERS_ROOT" "$DRIVERS_PKG"
	# macOS prompts to restart after NVIDIA Corporation has been initially allowed, without
	# rebuilding caches, which should be done AFTER team_id has been added to kext_policy
	if ! $KEXT_ALLOWED && [[ ! -z $UNAPPROVED_BUNDLES ]]; then
		warning "Don't restart until this process is complete."; fi
	printf '%bInstalling...%b\n' "$B" "$R"
	s /usr/sbin/installer -allowUntrusted -pkg "$DRIVERS_PKG" -target / || e "installer error" $?
else
	printf '%bInstalling...%b\n' "$B" "$R"
	/usr/bin/rsync -r "${DRIVERS_ROOT}"/* /
	NEEDS_KEXTCACHE=true
fi
etc "post-install.conf"

# Check extensions are loadable

s /sbin/kextload "$STARTUP_KEXT" # kextload returns 27 when a kext hasn't been approved yet
if [[ $? -eq 27 ]]; then
	/usr/bin/tput bel
	printf 'Allow NVIDIA Corporation in security preferences to continue...\n'
	NEEDS_KEXTCACHE=true
	while ! s /usr/bin/kextutil -tn "$STARTUP_KEXT"; do
		scpt "open-security-preferences.scpt"
		sleep 5
	done
fi

# Update caches, set nvram variable

check_required_os || NEEDS_KEXTCACHE=true
$NEEDS_KEXTCACHE && update_caches
$SET_NVRAM

# Exit

if $OPT_SYSTEM; then
	s rm -rf "$TMP_DIR"
	printf '%bSystem update...%b\n' "$B" "$R"
	$grep -iE -e "no updates|restart" <(/usr/sbin/softwareupdate -ir 2>&1) | /usr/bin/tail -1
fi
exit_after_changes "Installation complete."
