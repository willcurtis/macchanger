\
    #!/usr/bin/env bash
    #
    # macchanger for macOS - Spoof / fake MAC addresses
    #
    # Original author: shilch (https://github.com/shilch/macchanger)
    # Modernised by:   Will Curtis (https://github.com/willcurtis) and contributors
    #
    # This is a refreshed version of the original 2016 script, updated for
    # current macOS releases and shell best practices.

    set -euo pipefail

    VERSION="1.0.0"
    AUTHOR="Original: shilch; Updates: Will Curtis and contributors"
    YEAR="2016-2025"
    SCRIPT_NAME="macchanger"

    # --- Colours / formatting ----------------------------------------------------

    # Decide if we should use colour:
    # - Use colour only when stdout is a TTY
    # - Honour NO_COLOR env var if set
    use_color=true
    if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
      use_color=false
    fi

    if command -v tput >/dev/null 2>&1; then
      BOLD="$(tput bold || true)"
      NORMAL="$(tput sgr0 || true)"
    else
      BOLD=""
      NORMAL=""
    fi

    if $use_color; then
      RED=$'\\033[0;31m'
      BLUE=$'\\033[0;34m'
      YELLOW=$'\\033[0;33m'
      RS=$'\\033[0m'
    else
      RED=""
      BLUE=""
      YELLOW=""
      RS=""
    fi

    ERROR="${BOLD}${RED}ERROR:${RS}${NORMAL}   "
    INFO="${BOLD}${BLUE}INFO:${RS}${NORMAL}    "
    WARNING="${BOLD}${YELLOW}WARNING:${RS}${NORMAL} "

    # --- Helpers -----------------------------------------------------------------

    die() {
      printf "%s%s\\n" "${ERROR}" "$*" >&2
      exit 1
    }

    require_command() {
      local cmd=$1
      command -v "${cmd}" >/dev/null 2>&1 || die "Required command '${cmd}' not found in PATH"
    }

    ensure_darwin() {
      if [[ "$(uname -s)" != "Darwin" ]]; then
        die "${SCRIPT_NAME} is only supported on macOS"
      fi
    }

    ensure_root() {
      if [[ "${EUID}" -ne 0 ]]; then
        die "Run ${SCRIPT_NAME} as root: sudo ${SCRIPT_NAME} [option] [device]"
      fi
    }

    ensure_device_exists() {
      local dev=$1
      if ! ifconfig "${dev}" >/dev/null 2>&1; then
        die "Unable to find device/interface '${dev}'. Is it present and not disabled?"
      fi
    }

    find_airport_bin() {
      local candidates=(
        "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport"
      )

      for path in "${candidates[@]}"; do
        if [[ -x "${path}" ]]; then
          AIRPORT_BIN="${path}"
          return
        fi
      done

      AIRPORT_BIN=""
    }

    get_type() {
      local dev=$1
      ifconfig "${dev}" 2>/dev/null | awk -F'type: ' 'NF>1 {print $2; exit}' | awk '{print $1}'
    }

    current_mac() {
      local dev=$1
      local current
      current=$(ifconfig "${dev}" 2>/dev/null | awk '/ether/ {print $2; exit}')
      if [[ -z "${current}" ]]; then
        die "Unable to read current MAC address for '${dev}'"
      fi
      printf "%s" "${current}"
    }

    permanent_mac() {
      local dev=$1
      networksetup -getmacaddress "${dev}" 2>/dev/null | awk '{print $3}'
    }

    warn_multicast() {
      local mac=$1
      local first_octet
      first_octet=${mac%%:*}
      local dec=$((16#${first_octet}))
      if (( dec % 2 )); then
        printf "%sMAC address '%s' is multicast. It may not work as a host address.\\n" "${WARNING}" "${mac}"
      fi
    }

    generate_mac() {
      require_command openssl
      local bytes first_hex first_int
      bytes=$(openssl rand -hex 6) || die "Failed to generate random bytes via openssl"
      first_hex=${bytes:0:2}
      first_int=$(( 0x${first_hex} ))
      # Set locally-administered bit, clear multicast bit
      first_int=$(( (first_int | 0x02) & 0xFE ))
      first_hex=$(printf '%02x' "${first_int}")
      printf '%s:%s:%s:%s:%s:%s' \
        "${first_hex}" "${bytes:2:2}" "${bytes:4:2}" "${bytes:6:2}" "${bytes:8:2}" "${bytes:10:2}"
    }

    lookup_vendor() {
      local mac=$1
      local oui_file
      oui_file=${MACCHANGER_OUI_PATH:-}

      if [[ -z "${oui_file}" ]]; then
        local candidates=(
          "/usr/share/misc/oui.txt"
          "/usr/share/ieee-data/oui.txt"
          "/usr/local/share/wireshark/manuf"
        )
        for f in "${candidates[@]}"; do
          if [[ -r "${f}" ]]; then
            oui_file="${f}"
            break
          fi
        done
      fi

      if [[ -z "${oui_file}" || ! -r "${oui_file}" ]]; then
        printf "Unknown (OUI database not found)"
        return
      fi

      local prefix
      prefix=${mac:0:8}
      prefix=${prefix^^}
      prefix=${prefix//:/-}

      local vendor
      vendor=$(grep -i -m1 -E "^${prefix}[[:space:]]" "${oui_file}" 2>/dev/null | sed -E 's/^[^[:space:]]+[[:space:]]+//')

      if [[ -z "${vendor}" ]]; then
        printf "Unknown"
      else
        printf "%s" "${vendor}"
      fi
    }

    set_mac() {
      local dev=$1
      local mac=$2

      local type
      type=$(get_type "${dev}" || true)

      if [[ "${type}" == "Wi-Fi" && -n "${AIRPORT_BIN:-}" ]]; then
        printf "%sType of interface is Wi-Fi, disassociating from any network.\\n" "${INFO}"
        "${AIRPORT_BIN}" -z || true
      fi

      if ! ifconfig "${dev}" ether "${mac}" >/dev/null 2>&1; then
        die "Failed to set MAC address on device '${dev}'. Does the driver support spoofing?"
      fi

      if [[ "${type}" == "Wi-Fi" ]]; then
        networksetup -detectnewhardware >/dev/null 2>&1 || true
      fi
    }

    print_header() {
      local dev=$1
      local type perm current vendor
      type=$(get_type "${dev}" || printf "Unknown")
      perm=$(permanent_mac "${dev}")
      current=$(current_mac "${dev}")
      vendor=$(lookup_vendor "${current}")

      printf "%sType of device:%s        %s\\n" "${BOLD}" "${NORMAL}" "${type}"
      printf "%sPermanent MAC address:%s %s\\n" "${BOLD}" "${NORMAL}" "${perm}"
      printf "%sCurrent MAC address:%s   %s\\n" "${BOLD}" "${NORMAL}" "${current}"
      printf "%sCurrent vendor:%s        %s\\n" "${BOLD}" "${NORMAL}" "${vendor}"
    }

    list_devices() {
      printf "%sAvailable network devices:%s\\n" "${BOLD}" "${NORMAL}"
      if command -v networksetup >/dev/null 2>&1; then
        networksetup -listallhardwareports
      else
        ifconfig -l
      fi
    }

    usage() {
      cat <<EOF
    Usage: sudo ${SCRIPT_NAME} [option] [device]

    Options:
      -r, --random           Generate a random MAC and set it on the device
      -m, --mac MAC          Set a custom MAC address, e.g. ${SCRIPT_NAME} -m aa:bb:cc:dd:ee:ff en0
      -p, --permanent        Reset the MAC address to the permanent hardware value
      -s, --show             Show the current and permanent MAC address (plus vendor info)
      -l, --list-devices     List network devices as seen by macOS
      -V, --version          Print version information
      -h, --help             Show this help text

    Environment:
      MACCHANGER_OUI_PATH    Optional path to an IEEE OUI database for vendor lookup.
      NO_COLOR               Disable coloured output if set.

    Examples:
      sudo ${SCRIPT_NAME} -r en0
      sudo ${SCRIPT_NAME} -m aa:bb:cc:dd:ee:ff en0
      sudo ${SCRIPT_NAME} -p en0
      sudo ${SCRIPT_NAME} -s en0
    EOF
    }

    print_version() {
      printf "Version: %s, Copyright %s by %s\\n" "${VERSION}" "${YEAR}" "${AUTHOR}"
    }

    main() {
      ensure_darwin
      ensure_root

      require_command ifconfig
      require_command networksetup
      find_airport_bin

      if [[ $# -eq 0 ]]; then
        usage
        exit 1
      fi

      local opt=$1
      case "${opt}" in
        -V|--version)
          print_version
          ;;
        -h|--help)
          usage
          ;;
        -l|--list-devices)
          list_devices
          ;;
        -s|--show)
          local dev=${2:-}
          [[ -z "${dev}" ]] && die "Please specify your device/interface (e.g. en0)"
          ensure_device_exists "${dev}"
          print_header "${dev}"
          ;;
        -r|--random)
          local dev=${2:-}
          [[ -z "${dev}" ]] && die "Please specify your device/interface (e.g. en0)"
          ensure_device_exists "${dev}"

          local old new
          old=$(current_mac "${dev}")
          new=$(generate_mac)

          set_mac "${dev}" "${new}"
          new=$(current_mac "${dev}")

          if [[ "${old}" == "${new}" ]]; then
            die "Failed to change MAC address on '${dev}' – it did not change"
          fi

          printf "%sPermanent MAC address:%s %s\\n" "${BOLD}" "${NORMAL}" "$(permanent_mac "${dev}")"
          printf "%sOld MAC address:%s       %s\\n" "${BOLD}" "${NORMAL}" "${old}"
          printf "%sNew MAC address:%s       %s\\n" "${BOLD}" "${NORMAL}" "${new}"
          ;;
        -m|--mac)
          local mac=${2:-}
          local dev=${3:-}
          [[ -z "${mac}" || -z "${dev}" ]] && die "Usage: ${SCRIPT_NAME} -m aa:bb:cc:dd:ee:ff en0"

          warn_multicast "${mac}"
          ensure_device_exists "${dev}"

          local old
          old=$(current_mac "${dev}")
          set_mac "${dev}" "${mac}"

          printf "%sPermanent MAC address:%s %s\\n" "${BOLD}" "${NORMAL}" "$(permanent_mac "${dev}")"
          printf "%sOld MAC address:%s       %s\\n" "${BOLD}" "${NORMAL}" "${old}"
          printf "%sNew MAC address:%s       %s\\n" "${BOLD}" "${NORMAL}" "$(current_mac "${dev}")"
          ;;
        -p|--permanent)
          local dev=${2:-}
          [[ -z "${dev}" ]] && die "Please specify your device/interface (e.g. en0)"
          ensure_device_exists "${dev}"

          local old perm
          old=$(current_mac "${dev}")
          perm=$(permanent_mac "${dev}")

          set_mac "${dev}" "${perm}"

          printf "%sPermanent MAC address:%s %s\\n" "${BOLD}" "${NORMAL}" "${perm}"
          printf "%sOld MAC address:%s       %s\\n" "${BOLD}" "${NORMAL}" "${old}"
          printf "%sNew MAC address:%s       %s\\n" "${BOLD}" "${NORMAL}" "$(current_mac "${dev}")"
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    }

    main "$@"
