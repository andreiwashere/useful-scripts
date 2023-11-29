#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

[ "${VERBOSE:-0}" == "1" ] && set -v
[ "${DEBUG:-0}" == "1" ] && set -x

declare ARG1
ARG1="${1:-help}"

if [[ "${ARG1}" == "-h" || "${ARG1}" == "help" || "${ARG1}" == "--help" ]]; then
  cat << EOF
Usage: ${0##*/} [options]

Fix VPN routes for SSH.

Options:
  -h, --help, help             Display this help and exit.
  -i, --install, install       Install VPN Workaround
  -u, --uninstall, uninstall   Uninstall VPN Workaround

Examples:
  ${0##*/}                      # Install Intranet Firewall Policies
  VERBOSE=1 ${0##*/}            # Install in verbose mode
  DEBUG=1 ${0##*/}              # Install in debug mode

EOF
  exit 1
fi

declare LOCKFILE
LOCKFILE=/root/vpn-route-workaround.lock
if [[ -s "${LOCKFILE}" ]]; then
  echo "Already running another process of ${0##*/}."
  exit 1
fi

echo 1 | tee "${LOCKFILE}" > /dev/null

function cleanup(){
  rm -rf "${LOCKFILE}"
}

trap cleanup EXIT INT TERM

declare HOST_IP
declare IP_OK
declare BREAK_ME
declare HOST_SUBNET
declare HOST_GATEWAY
declare IP_REGEX='^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
while true; do
  IP_OK=0
  BREAK_ME=0
  read -r -p "Enter this host's IP Address [$(hostname -I | awk '{print $1}')]: " HOST_IP
  if [[ "${HOST_IP}" == "" ]]; then
    HOST_IP="$(hostname -I | awk '{print $1}')"
  fi
  if [[ $HOST_IP =~ $IP_REGEX ]]; then
    read -r -p "Is ${HOST_IP} correct? [y|n*]: " -t 300 IP_OK
    case "${IP_OK}" in
      [Yy]*) BREAK_ME=1; break;;
      *) echo "Timed out waiting for you to confirm this looks good. Not gonna wait around all day for you."; exit 1;;
    esac
    [[ "${BREAK_ME}" == "1" ]] && break
  else
    echo "Invalid IP Address: ${HOST_IP}. Please try again."
  fi
done

IFS='.' read -r -a ip_parts <<< "${HOST_IP}"
HOST_SUBNET="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.0/24"
HOST_GATEWAY="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.254"

declare TABLE_ID="${2:-UNDEFINED}"
declare -i DEFAULT_TABLE_ID=128
declare TABLE_ID_REGEX='^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-2])$'
if [[ "${TABLE_ID}" == "UNDEFINED" ]] || ! [[ $TABLE_ID =~ $TABLE_ID_REGEX ]]; then
  read -r -p "Route Table ID [${DEFAULT_TABLE_ID}]: " TABLE_ID
  if [[ -z "${TABLE_ID}" ]] || ! [[ $TABLE_ID =~ $TABLE_ID_REGEX ]]; then
    echo "Invalid or no Table ID entered. Using default ID ${DEFAULT_TABLE_ID}."
    TABLE_ID=$DEFAULT_TABLE_ID
  fi
fi

declare INTERFACE
declare DEFAULT_INTERFACE
declare INTERFACE_CHECK
while true; do
  INTERFACE=""
  DEFAULT_INTERFACE="$(ip -4 addr show | grep -B2 "${HOST_IP}" | head -n1 | awk '{print $2}' | sed 's/://')"
  while true; do
    echo "Applying this route policy against the network interface ${DEFAULT_INTERFACE}."
    read -r -p "To change which interface to modify, specify the network interface here: [${DEFAULT_INTERFACE}]: " INTERFACE
    if [[ -z "${INTERFACE}" ]]; then
      INTERFACE=$DEFAULT_INTERFACE
      break
    elif [[ "${INTERFACE}" == "exit" ]]; then
      echo "Easter Egg found! We'll bail outta here for you."
      exit 1
    elif [[ "${INTERFACE}" == "${DEFAULT_INTERFACE}" ]]; then
      echo "Well aren't you cute."
      break
    else
      echo "Invalid interface: ${INTERFACE}"
      ip -4 addr show | grep -B2 "${HOST_IP}"
      echo "Please try again."
    fi
  done

  INTERFACE_CHECK="$({ ip -4 addr show | grep "${INTERFACE}" | grep "${HOST_IP}" > /dev/null 2>&1 && echo "OK"; } || echo "FAIL")"
  if [[ "${INTERFACE_CHECK}" == "FAIL" ]]; then
    echo "INVALID INTERFACE SPECIFIED."
  else
    break
  fi
done

declare TEST_VPN
while true; do
  echo "Do you want this script to: "
  echo "1. DISCONNECT from the VPN"
  echo "2. CONNECT to the VPN"
  echo "3. SAVE the route table to /root/install.ip.route.show.table.all.connected.before"
  echo "4. DISCONNECT from the VPN"
  echo "5. SAVE the route table to /root/install.ip.route.show.table.all.disconnected.before"
  echo "6. INSERT route table ID ${TABLE_ID}"
  echo "7. INSERT route ${HOST_SUBNET} on ${INTERFACE} in table ID ${TABLE_ID}"
  echo "8. INSERT route ${HOST_GATEWAY} on ${INTERFACE} in table ID ${TABLE_ID}"
  echo "9. CONNECT to the VPN"
  echo "10. SAVE the route table to /root/install.ip.route.show.table.all.connected.after"
  echo "11. DISCONNECT from the VPN"
  echo "12. SAVE the route table to /root/install.ip.route.show.table.all.disconnected.after"
  echo

  if [[ "${ARG1}" == "-i" || "${ARG1}" == "install" || "${ARG1}" == "--install" ]]; then
    read -r -p "INSTALL: Do you want to connect/disconnect to/from the VPN? [y|n*] " TEST_VPN
  elif [[ "${ARG1}" == "-u" || "${ARG1}" == "uninstall" || "${ARG1}" == "--uninstall" ]]; then
    read -r -p "UNINSTALL: We good? [y|n*]: " TEST_VPN
  else
    read -r -p "Do you want to perform VPN connect/disconnect commands? [y|n*]: " TEST_VPN
  fi
  case "${TEST_VPN}" in
    [Yy]*)
      if command -v connect &> /dev/null; then
        if command -v disconnect &> /dev/null; then
          TEST_VPN=1
        else
          TEST_VPN=0
        fi
      else
        TEST_VPN=0
      fi
      break
      ;;
    [Nn]*)
      TEST_VPN=0
      break
      ;;
    *)
      echo "Invalid choice."
      ;;
  esac
done

if [[ "${ARG1}" == "-i" || "${ARG1}" == "install" || "${ARG1}" == "--install" ]]; then
  [[ "${TEST_VPN}" == "1" ]] && disconnect
  [[ "${TEST_VPN}" == "1" ]] && connect
  sudo ip route show table all | sudo tee "/root/install.ip.route.show.table.all.connected.before" > /dev/null
  [[ "${TEST_VPN}" == "1" ]] && disconnect
  sudo ip route show table all | sudo tee "/root/install.ip.route.show.table.all.disconnected.before" > /dev/null

  sudo ip rule add from "${HOST_IP}" table "${TABLE_ID}"
  sudo ip route add table "${TABLE_ID}" to "${HOST_SUBNET}" dev "${INTERFACE}"
  sudo ip route add table "${TABLE_ID}" default via "${HOST_GATEWAY}"

  [[ "${TEST_VPN}" == "1" ]] && connect
  sudo ip route show table all | sudo tee "/root/install.ip.route.show.table.all.connected.after" > /dev/null
  [[ "${TEST_VPN}" == "1" ]] && disconnect
  sudo ip route show table all | sudo tee "/root/install.ip.route.show.table.all.disconnected.after" > /dev/null
  exit 0
fi

if [[ "${ARG1}" == "-u" || "${ARG1}" == "uninstall" || "${ARG1}" == "--uninstall" ]]; then
  sudo ip route show table all | sudo tee "/root/uninstall.ip.route.show.table.all.before" > /dev/null
  sudo ip route del table "${TABLE_ID}" to "${HOST_SUBNET}" dev "${INTERFACE}"
  sudo ip route del table "${TABLE_ID}" default via "${HOST_GATEWAY}"
  sudo ip rule del from "${HOST_IP}" table "${TABLE_ID}"
  sudo ip route show table all | sudo tee "/root/uninstall.ip.route.show.table.all.after" > /dev/null
  exit 0
fi

