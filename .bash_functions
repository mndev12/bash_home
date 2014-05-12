#-------------------------------------------------------------
# Get X Server
#-------------------------------------------------------------
function get_xserver ()
{
    case $TERM in
        xterm )
            XSERVER=$(who am i | awk '{print $NF}' | tr -d ')''(' )
            # Ane-Pieter Wieringa suggests the following alternative:
            # I_AM=$(who am i)
            # SERVER=${I_AM#*(}
            # SERVER=${SERVER%*)}
            XSERVER=${XSERVER%%:*}
            ;;
            aterm | rxvt)
            # Find some code that works here. ...
            ;;
    esac
}

if [ -z ${DISPLAY:=""} ]; then
get_xserver
    if [[ -z ${XSERVER} || ${XSERVER} == $(hostname) ||
       ${XSERVER} == "unix" ]]; then
DISPLAY=":0.0" # Display on local host.
    else
DISPLAY=${XSERVER}:0.0 # Display on remote host.
    fi
fi

export DISPLAY

#-------------------------------------------------------------
# Extract Program
#-------------------------------------------------------------
function extract()
{
    if [ -f $1 ] ; then
case $1 in
            *.tar.bz2) tar xvjf $1 ;;
            *.tar.gz) tar xvzf $1 ;;
            *.bz2) bunzip2 $1 ;;
            *.rar) unrar x $1 ;;
            *.gz) gunzip $1 ;;
            *.tar) tar xvf $1 ;;
            *.tbz2) tar xvjf $1 ;;
            *.tgz) tar xvzf $1 ;;
            *.zip) unzip $1 ;;
            *.Z) uncompress $1 ;;
            *.7z) 7z x $1 ;;
            *) echo "'$1' cannot be extracted via >extract<" ;;
        esac
else
echo "'$1' is not a valid file!"
    fi
}

#-------------------------------------------------------------
# Make
#-------------------------------------------------------------
_make()
{
    local mdef makef makef_dir="." makef_inc gcmd cur prev i;
    COMPREPLY=();
    cur=${COMP_WORDS[COMP_CWORD]};
    prev=${COMP_WORDS[COMP_CWORD-1]};
    case "$prev" in
        -*f)
            COMPREPLY=($(compgen -f $cur ));
            return 0
            ;;
    esac;
    case "$cur" in
        -*)
            COMPREPLY=($(_get_longopts $1 $cur ));
            return 0
            ;;
    esac;

    # ... make reads
    # GNUmakefile,
    # then makefile
    # then Makefile ...
    if [ -f ${makef_dir}/GNUmakefile ]; then
        makef=${makef_dir}/GNUmakefile
    elif [ -f ${makef_dir}/makefile ]; then
        makef=${makef_dir}/makefile
    elif [ -f ${makef_dir}/Makefile ]; then
        makef=${makef_dir}/Makefile
    else
       makef=${makef_dir}/*.mk # Local convention.
    fi


    # Before we scan for targets, see if a Makefile name was
    #+ specified with -f.
    for (( i=0; i < ${#COMP_WORDS[@]}; i++ )); do
        if [[ ${COMP_WORDS[i]} == -f ]]; then
            # eval for tilde expansion
            eval makef=${COMP_WORDS[i+1]}
            break
        fi
    done
    [ ! -f $makef ] && return 0

    # Deal with included Makefiles.
    makef_inc=$( grep -E '^-?include' $makef |
                 sed -e "s,^.* ,"$makef_dir"/," )
    for file in $makef_inc; do
        [ -f $file ] && makef="$makef $file"
    done


    # If we have a partial word to complete, restrict completions
    #+ to matches of that word.
    if [ -n "$cur" ]; then gcmd='grep "^$cur"' ; else gcmd=cat ; fi

    COMPREPLY=( $( awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ \
                               {split($1,A,/ /);for(i in A)print A[i]}' \
                                $makef 2>/dev/null | eval $gcmd ))

}

complete -F _make -X '+($*|*.[cho])' make gmake pmake

#-------------------------------------------------------------
# Test Connections
#-------------------------------------------------------------

if [ -n "${SSH_CONNECTION}" ]; then
CNX=${Green} # Connected on remote machine, via ssh (good).
elif [[ "${DISPLAY%%:0*}" != "" ]]; then
CNX=${ALERT} # Connected on remote machine, not via ssh (bad).
else
CNX=${BCyan} # Connected on local machine.
fi


#-------------------------------------------------------------
# Test User
#-------------------------------------------------------------

if [[ ${USER} == "root" ]]; then
SU=${Red} # User is root.
elif [[ ${USER} != $(logname) ]]; then
SU=${BRed} # User is not login user.
else
SU=${BCyan} # User is normal (well ... most of us are).
fi

NCPU=$(grep -c 'processor' /proc/cpuinfo) # Number of CPUs
SLOAD=$(( 100*${NCPU} )) # Small load
MLOAD=$(( 200*${NCPU} )) # Medium load
XLOAD=$(( 400*${NCPU} )) # Xlarge load

#-------------------------------------------------------------
# Load Percentage
#-------------------------------------------------------------

function load()
{
    local SYSLOAD=$(cut -d " " -f1 /proc/loadavg | tr -d '.')
    # System load of the current host.
    echo $((10#$SYSLOAD)) # Convert to decimal.
}

#-------------------------------------------------------------
# Color of SystemLoad
#-------------------------------------------------------------

function load_color()
{
    local SYSLOAD=$(load)
    if [ ${SYSLOAD} -gt ${XLOAD} ]; then
echo -en ${ALERT}
    elif [ ${SYSLOAD} -gt ${MLOAD} ]; then
echo -en ${Red}
    elif [ ${SYSLOAD} -gt ${SLOAD} ]; then
echo -en ${BRed}
    else
echo -en ${Green}
    fi
}


#-------------------------------------------------------------
# Disk Color
#-------------------------------------------------------------

function disk_color()
{
    if [ ! -w "${PWD}" ] ; then
echo -en ${Red}
        # No 'write' privilege in the current directory.
    elif [ -s "${PWD}" ] ; then
local used=$(command df -P "$PWD" |
                   awk 'END {print $5} {sub(/%/,"")}')
        if [ ${used} -gt 95 ]; then
echo -en ${ALERT} # Disk almost full (>95%).
        elif [ ${used} -gt 90 ]; then
echo -en ${BRed} # Free disk space almost gone.
        else
echo -en ${Green} # Free disk space is ok.
        fi
else
echo -en ${Cyan}
        # Current directory is size '0' (like /proc, /sys etc).
    fi
}


#-------------------------------------------------------------
# Job Color
#-------------------------------------------------------------

function job_color()
{
    if [ $(jobs -s | wc -l) -gt "0" ]; then
echo -en ${BRed}
    elif [ $(jobs -r | wc -l) -gt "0" ] ; then
echo -en ${BCyan}
    fi
}

# Now we construct the prompt.
PROMPT_COMMAND="history -a"
case ${TERM} in
  *term | rxvt | linux)
        PS1="\[\$(load_color)\][\A\[${NC}\] "
        # Time of day (with load info):
        PS1="\[\$(load_color)\][\A\[${NC}\] "
        # User@Host (with connection type info):
        PS1=${PS1}"\[${SU}\]\u\[${NC}\]@\[${CNX}\]\h\[${NC}\] "
        # PWD (with 'disk space' info):
        PS1=${PS1}"\[\$(disk_color)\]\W]\[${NC}\] "
        # Prompt (with 'job' info):
        PS1=${PS1}"\[\$(job_color)\]>\[${NC}\] "
        # Set title of current xterm:
        PS1=${PS1}"\[\e]0;[\u@\h] \w\a\]"
        ;;
    *)
        PS1="(\A \u@\h \W) > " # --> PS1="(\A \u@\h \w) > "
                               # --> Shows full pathname of current dir.
        ;;
esac

export TIMEFORMAT=$'\nreal %3R\tuser %3U\tsys %3S\tpcpu %P\n'
export HISTIGNORE="&:bg:fg:ll:h"
export HISTTIMEFORMAT="$(echo -e ${BCyan})[%d/%m %H:%M:%S]$(echo -e ${NC}) "
export HISTCONTROL=ignoredups
export HOSTFILE=$HOME/.hosts # Put a list of remote hosts in ~/.hosts

#-------------------------------------------------------------
# Process/system related functions:
#-------------------------------------------------------------

function my_ps() { ps $@ -u $USER -o pid,%cpu,%mem,bsdtime,command ; }
function pp() { my_ps f | awk '!/awk/ && $0~var' var=${1:-".*"} ; }

#-------------------------------------------------------------
# Kill Program
#-------------------------------------------------------------

function killps() # kill by process name
{
    local pid pname sig="-TERM" # default signal
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
echo "Usage: killps [-SIGNAL] pattern"
        return;
    fi
if [ $# = 2 ]; then sig=$1 ; fi
for pid in $(my_ps| awk '!/awk/ && $0~pat { print $1 }' pat=${!#} )
    do
pname=$(my_ps | awk '$1~var { print $5 }' var=$pid )
        if ask "Kill process $pid <$pname> with signal $sig?"
            then kill $sig $pid
        fi
done
}

#-------------------------------------------------------------
# mydf
#-------------------------------------------------------------

function mydf() # Pretty-print of 'df' output.
{ # Inspired by 'dfc' utility.
    for fs ; do

if [ ! -d $fs ]
        then
echo -e $fs" :No such file or directory" ; continue
fi

local info=( $(command df -P $fs | awk 'END{ print $2,$3,$5 }') )
        local free=( $(command df -Pkh $fs | awk 'END{ print $4 }') )
        local nbstars=$(( 20 * ${info[1]} / ${info[0]} ))
        local out="["
        for ((j=0;j<20;j++)); do
if [ ${j} -lt ${nbstars} ]; then
out=$out"*"
            else
out=$out"-"
            fi
done
out=${info[2]}" "$out"] ("$free" free on "$fs")"
        echo -e $out
    done
}

#-------------------------------------------------------------
# External IP
#-------------------------------------------------------------

function my_ip() # Get IP adress on ethernet.
{
    MY_IP=$(/sbin/ifconfig eth0 | awk '/inet/ { print $2 } ' |
      sed -e s/addr://)
    echo ${MY_IP:-"Not connected"}
}

#-------------------------------------------------------------
# Host Info
#-------------------------------------------------------------

function ii() # Get current host related info.
{
    echo -e "\nYou are logged on ${BRed}$HOST"
    echo -e "\n${BRed}Additionnal information:$NC " ; uname -a
    echo -e "\n${BRed}Users logged on:$NC " ; w -hs |
             cut -d " " -f1 | sort | uniq
    echo -e "\n${BRed}Current date :$NC " ; date
    echo -e "\n${BRed}Machine stats :$NC " ; uptime
    echo -e "\n${BRed}Memory stats :$NC " ; free
    echo -e "\n${BRed}Diskspace :$NC " ; mydf / $HOME
    echo -e "\n${BRed}Local IP Address :$NC" ; my_ip
    echo -e "\n${BRed}Open connections :$NC "; netstat -an;
    echo
}

#-------------------------------------------------------------
# Net Info
#-------------------------------------------------------------

netinfo ()
{
echo "--------------- Network Information ---------------"
/sbin/ifconfig | awk /'inet addr/ {print $2}'
echo ""
/sbin/ifconfig | awk /'Bcast/ {print $3}'
echo ""
/sbin/ifconfig | awk /'inet addr/ {print $4}'

# /sbin/ifconfig | awk /'HWaddr/ {print $4,$5}'
echo "---------------------------------------------------"
}
