#! /bin/bash

#####################################################
# This is meant to be a guide to walk through parted expansions
######################################################

#######
# To Do:
#   - add colors in
#   - make it more versatile
#   - make a better progress bar/better logic
#######

#########
# Colors (if you so desire)
##########################
    BLACK='\033[30m'
    RED='\033[31m'
    GREEN='\033[32m'
    YELLO='\033[33m'
    BLUE='\033[34m'
    MAGENTA='\033[35m'
    CYAN='\033[36m'
    WHITE='\033[37m'
    RESET='\033[39m'
##########################

clean_up() { 
    # There really isn't much to clean up atm
    exit 1
}

##########################
# This is a trap, it will catch either a sigin, or term signal sent to this script and 
# run the clean_up function before the script is closed
##########################
trap clean_up SIGINT TERM

##########################
# This is the help function which runs when an incorrect variable is set, or 
# if the help flag is called
##########################
program_help(){
    printf """
Usage: %s (-flags)
 
This script is meant to guide you through the steps for adding or expanding a 
vdisk on a vm through parted. Please always be certain to verify the naming 
conventions of everything before you run. This script merely writes out changes
for copy/paste and does not actually make any changes. This script also assumes
LVM is in use.    
--------------------------------------------------------
    
    -a       Walk through steps for ADDing a NEW vdisk
    -e       Walk through steps for EXPANDing an EXISTING vdisk
    -f [1-6] Gives a random fact about parted, presently there are only 6 added     
    -d       Debug/verbose, much more output
    -h       Show this message
    -n       Disable all of the script checks and force a run anyways
    -v       Show script version\n""" "${1}"
}

##########################
# This function checks whether or not a package is installed
# if the package is not installed, then it exits with directions
# on how to obtain the package.
##########################
package_check(){
    if [[ ! $(which ${1} 2> /dev/null) ]]; then
        printf """\"${1}\" is not installed or is not in your \$PATH. \"${1}\" is required to run this script.

You can retrieve this by running:
    $ sudo dnf install ${2}
OR
    $ sudo apt-get install ${2}\n"""
        exit 1
     else :
     fi
}

lines_check(){
    if [[ $(tput lines) -lt 51 ]]; then
        echo "Sorry, the terminal needs to be atleast 51 lines long due to" 
        echo "how the script formats itself. Please resize and try again."
        echo "You can check the size with -- $ tput lines"
        exit 1
    fi
}

variables_check(){
    if [[ "${#@}" == 0 ]]; then
        echo "This script requires arguments. Please see the below help"
        program_help
        exit 0
    fi        
}

##########################
# These are where we place all the checks for our script, if more are
# needed, add them to yes. We have a check in place for a flag that will
# disable all these if needed.
##########################
script_checks(){
   case $1 in
       no ) :
           ;;
       yes )
            lines_check
            package_check tput ncurses
           ;;
    esac
}    



##########################
# This Function merely prints the version of the script
##########################
version_info(){
VERS="1.1"
printf "%s is on version %s\n" "$0" "$VERS"
}

##########################
# This function sets debug on for bash when -v is passed
# if you're running into issues, this is very handy
# for troubleshooting
##########################
debug_on(){
    if [[ "$1" == "on" ]]; then
        set -x
    else :
    fi
}

##########################
# This function sets debug off
##########################
debug_off(){
    set +x
}

##########################
# These functions are for controlling where the cursor goes 
##########################

ESC='\033'
current_position() { OFIS=$IFS;IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; IFS=$OIFS; }
save_position()    { printf "${ESC}[s"; }
return_position()  { printf "${ESC}[u"; }
erase_from_pos()   { printf "${ESC}[K"; }
set_new_position() { printf "${ESC}[${1};1H"; }
reset_screen()     { printf "${ESC}[2J"; }
reset_position()   { printf "${ESC}[f"; }

###########################
# This is a progress bar that sits at the top
###########################

progress_bar(){
    reset_position
    printf "Script Progress: [ ${1}%s ]\n-----------------------------------------" "%"
}

###########################
# This is a live message that shows what variables
# you are using in the script
###########################

message_post() { echo -n "[+] -- Loaded Variable ${2}: ${1}"; }

post_status(){
    message_post ${2} ${3}
    save_position
    progress_bar ${1} 
    return_position
}

###########################
# This sets the screen position and cursor position for the script
###########################

script_begin(){
    reset_screen
    progress_bar 0
    set_new_position 3
}

##########################
# We use this to store some of our variables so we can pull 
# them out for use in other functions
##########################
store_vars(){
    if [[ $1 == "PULL_MYVARS" ]]; then
        echo ${MY_VARS[@]}
    else
        MY_VARS=${@}
    fi
}

##########################
# This function gathers our information
##########################
gather_info(){
    disk_info(){
        progress_incre(){ PROG_VALUE=$(($1*15)); set_new_position ${2};
            post_status ${PROG_VALUE} ${3} ${4}; set_new_position 9; erase_from_pos; }
        k=0
        l=2
        set_new_position 9
        read -p "Ticket Number: " TCKT; ((k++)); ((l++))
        progress_incre ${k} ${l} ${TCKT} Ticket
        read -p "Device Number (/dev/sd...): " DVNME; ((k++)); ((l++))
        progress_incre ${k} ${l} ${DVNME} Device
        read -p "Volume group name: " VGNME; ((k++)); ((l++))
        progress_incre ${k} ${l} ${VGNME} VG
        read -p "Logical Volume group name: " LVGNME; ((k++)); ((l++))
        progress_incre ${k} ${l} ${LVGNME} LV
    }

    if [[ "${1}" == "confirm_expand" ]]; then
        disk_info
        read -p "Partition Number (is it the 2,3,4 etc... partition?): " PARTNMBR; ((k++)); ((l++))
        progress_incre ${k} ${l} ${PARTNMBR} Part-Number
        read -p "Provide the start sector (number only) for where the new Parition begins.
If you are uncertain what that is, reply with [h]: " SECSTART; ((k++)); ((l++))
        case ${SECSTART} in 
            [h-H] ) 
                set_new_position 9
                printf """Run the following command to pull the sector:
    $ sudo parted ${DVNME} unit s print | awk '/^ [0-9].*[0-9]{4}s/ {gsub(/s/,\"\",\$0); print \$3}' | sed -ne '\$p' | xargs -i sh -c 'i={};  echo \$i+1 | bc -l'\"\n""" 
                read -p "Sector start: " SECSTART
                ;;
            * ) 
                if [[ ${SECSTART} =~ [a-zA-Z] ]]; then
                    echo "Please check '${SECSTART}' should only contain numbers."
                    exit 1 
                fi
                ;;
        esac
        progress_incre ${k} ${l} ${SECSTART} Sector
    else
        disk_info
    fi
    store_vars ${TCKT} ${DVNME} ${VGNME} ${LVGNME} ${SECSTART} ${PARTNMBR}
}

##########################
# This goes over steps for scanning
##########################
scan_steps(){
    set_new_position 9
    printf """
Steps You Will Run
-----------------------------------------
{~} Check sectors/naming conventions before
pvs; vgs; lvs; lsblk; df -Ph
parted ${2} unit s print

{~} Rescan the scsi bus. If this is for SAN and ASM is in use, use add_lun.sh. DO NOT run this.
    # invididual disk --
echo 1 > /sys/block/${VARARR[1]#*\/*\/}/device/rescan
    # scsi bus --
for x in /sys/class/scsi_host/host*/scan; do echo \"- - -\" > \${x}; done

{~} Check
lsblk; dmesg | tail
parted ${2} unit s print\n"""
}

##########################
# This function goes over steps for lvm
##########################
lvm_steps(){
    if [[ -z ${6} ]]; then
        DISK_VALUE="1"
    else
        DISK_VALUE="${6}"
    fi
    
    printf """
{~} Create a physical volume with the new partition, add it to the volume group, and expand/resize
screen -LS ${1}
pvcreate --metadatasize 250k ${2}${DISK_VALUE}
vgextend ${3} ${2}${DISK_VALUE}
lvextend -l +100%sFREE /dev/mapper/${3}-${4}
resize2fs /dev/mapper/${3}-${4}\n""" "%"
}    
##########################
# This function goes over steps when adding a vdisk
##########################
adding_steps(){
    gather_info 
    for POSITION in {9..12}; do
        set_new_position ${POSITION}
        erase_from_pos
    done
    
    OIFS=$IFS;IFS=$'\n'
    MY_VARS=$(store_vars PULL_MYVARS)
    while read INPUT; do
        VARARR+=("${INPUT}")
    done <<<$(echo ${MY_VARS} | sed 's/ /\n/g')
    IFS=$OIFS
    scan_steps ${VARARR[@]}

    printf """
{~} The below will create a gpt partition using the entire disk
parted -s -- ${VARARR[1]} mklabel gpt
parted -s -a optimal -- ${VARARR[1]} mkpart primary${VARARR[1]#*\/*\/} 2048s 100%s
parted -s -- ${VARARR[1]} align-check optimal 1
parted ${VARARR[1]} set 1 lvm on
parted ${VARARR[1]} unit s print\n""" "%"
    lvm_steps ${VARARR[@]}
}    

##########################
# This function goes over steps when expanding a vdisk
##########################
expand_steps(){
    gather_info confirm_expand
    for POSITION in {9..15}; do
        set_new_position ${POSITION}
        erase_from_pos
    done

    set_new_position 9
    OIFS=$IFS;IFS=$'\n'
    MY_VARS=$(store_vars PULL_MYVARS)
    while read INPUT; do
        VARARR+=("${INPUT}")
    done <<<$(echo ${MY_VARS} | sed 's/ /\n/g')
    IFS=$OIFS
    scan_steps ${VARARR[@]}

    printf """
{~} The below will create a gpt partition using the rest of the disk
parted -s -- ${VARARR[1]} mklabel gpt
parted -s -a optimal -- ${VARARR[1]} mkpart  primary${VARARR[1]#*\/*\/}${VARARR[5]} ${VARARR[4]}s 100%s
parted ${VARARR[1]} set ${VARARR[5]} lvm on
parted ${VARARR[1]} unit s print

{~} Use the below to ensure the kernel picks up the new space
ls ${VARARR[1]}*; grep ${VARARR[1]#*\/*\/} /proc/partitions
partx -v -a ${VARARR[1]}
ls ${VARARR[1]}*; grep ${VARARR[1]#*\/*\/} /proc/partitions\n""" "%"
    lvm_steps ${VARARR[@]}
}    

##########################
# This function spits out a random parted fact
##########################

parted_fact(){
    if [[ -z $1 ]]; then 
        FACT_NUM=$(( 1 + $RANDOM % 6 ))
    elif [[ $1 =~ [1-6] ]]; then
        FACT_NUM=${1}
    fi

    printf "\nRandom Fun Fact!\n-----------------------------------------\n"

    case ${FACT_NUM} in
      1 ) echo 'Parted stands for PARTition EDitor'
      ;;
      2 ) echo 'Parted writes changed immediately to reduce chance of '
          echo 'data loss in the event of a power or other outage'
      ;;
      3 ) echo 'Unambiguous abbreviations are allowed. For example, you'
          echo 'can type “p” instead of “print”, and “u” instead of “units”.'
      ;;
      4 ) echo 'Parted is written in C by  Andrew Clausen and Lennert Buytenhek.'
          echo 'It is being maintenance by Phillip Susi and Brian C. Lane.'
      ;;
      5 ) echo 'Parted uses the GNU General Public License V3+. This license'
          echo 'guarantees end users the freedom to run, study, share and modify the software.'
      ;;    
      6 ) echo 'The reason the label for each partition is uniquely named, is because starting'
          echo 'in rhel 7 duplicate labels cause issues with udev rules'
      ;;
    esac
    POS_RETURN=$(current_position)
    progress_bar 100
    set_new_position ${POS_RETURN}
}    

##########################
# This ifstatement is what tells us whether we will have
# debug set to on or off. The next one tells us whether 
# or not we will enable checks. We feed this option to our
# function which reads all of the checks. Everything is much 
# more centralized, and checks can be added/removed easily.
##########################
if [[ "${@}" =~ "-d" ]]; then
    debug='on'
else
    debug='off'
fi

if [[ "${@}" =~ "-n" ]]; then
    checks='no'
else
    checks='yes'
fi

variables_check ${@}
script_checks ${checks}

##########################
# This parses all of the arguments passed to the script
# when adding to this, if the argument requires a parameter
# add it to before the colon, if it does not, add it after
# the colon. i.e. if you need to pass "-N 1254-15775" to the
# script, then change the below to ":N:dhnv", if you just
# need to pass a flag (-N), but it doesn't need an argument, then
# add it after ":dhnvN"
##########################

while getopts "f:dhnvae" arguments; do
    case ${arguments} in
        a ) 
            script_begin           
            adding_steps
            parted_fact
            exit 0
            ;;
        e ) 
            script_begin
            expand_steps
            parted_fact
            exit 0
            ;;
        f ) parted_fact ${OPTARG}
            exit 0
            ;;
        h ) 
            debug_on ${debug}
            program_help ${0}
            debug_off
            exit 0
            ;;
        n ) debug_on ${debug}
            debug_off
            ;;
        v ) 
            debug_on ${debug}
            version_info 
            debug_off
            exit 0
            ;;
        : ) 
            printf "%s: '%s' requires additional parameteres\n" "${0}" "-$OPTARG" 1>&2
            exit 1
            ;;
        \? ) 
            printf "Invalid Option: -$OPTARG" 1>&2
            program_help ${0}
            exit 1
            ;;
        *  )
            printf "Unimplemented option: -$OPTARG" >&2
            program_help ${0}
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))
