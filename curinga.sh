#!/bin/bash

yellow=$(tput setaf 3)
blue=$(tput setaf 4)
lblue=$(tput setaf 6)
reset=$(tput sgr0)
red=$(tput setaf 1)
white=$(tput setaf 7)

sorbs_delist() {

    SARGS="$1"
    if [ -z "$1" ];then
        SARGS=$(hostname -i)
    fi
    python <(curl -k -s http://legal.hostdime.com/andrewd_env/sorbs.py) "$SARGS"
}

function topdomains {
        files=$(domains=$(cat /etc/userdomains | cut -f1 -d: | head -n $(($(wc -l /etc/userdomains | cut -f1 -d\ ) - 1 ))); for i in ${domains}; do find /usr/local/apache/domlogs -maxdepth 1 -type f -ctime 0 -name ${i} ; done); echo -e "Hits\t\tDomain";for i in ${files}; do echo -e "$(grep -P $(date +%d/%b/%Y) ${i} | wc -l)\t\t$(basename ${i})"; done | sort -rn | head

}

function showcon {
    netstat -pltuna | awk '$6=="LISTEN"{sub(/^.*:+/,"",$4);sub(/^[[:digit:]]+\//,"",$7);idx=sprintf("%s:%05d",$1,$4);ary[idx]=$7;} $6~"^(ESTABLISHED|SYN_RECV|FIN_WAIT2|UNKNOWN)$"{sub(/^.*:(:ffff:)?/,"",$4);sub(/:[[:digit:]]+$/,"",$5);sub(/^::ffff:/,"",$5);idx=sprintf("%s:%05d@%s",$1,$4,$5);cons[idx]++;}END{LIMITS["def"]=30;LIMITS[21]=8;LIMITS[25]=5;LIMITS[26]=5;LIMITS[465]=5;LIMITS[587]=5;CL_NML="\033[0m";CL_WTE="\033[1;37m";CL_GRN="\033[0;32m";CL_YLW="\033[1;36m";CL_RED="\033[1;5;31;22;47m";n=asorti(ary,src);for(i=1;i<=n;i++){split(src[i],meh,/:/);sub(/^0*/,"",meh[2]);print CL_WTE ary[src[i]] CL_NML " " CL_GRN "(" meh[1] ":" meh[2] ")" CL_NML ":";delete nastyhack;for (q in cons){split(q,splt,/@/);if(match(splt[1],src[i])){fmtstr=sprintf("%010d %s",cons[q],splt[2]);nastyhack[fmtstr]=fmtstr;}}r=asort(nastyhack);zerocount=match(nastyhack[r],/[^0]/);for (m=1;m<=r;m++){nastyhack[m]=substr(nastyhack[m],zerocount);split(nastyhack[m],brg,/ /);printf CL_YLW brg[1] CL_NML " ";port=meh[2];if(!(port in LIMITS)) port="def";if (brg[1]>LIMITS[port]) printf CL_RED;print brg[2] CL_NML;}}}'
}

function quickmail() {
    find /var/spool/exim/input/ -type f -name '*-H' -exec grep -Eq $1 '{}' \; -and -print | awk -F/ '{system("");sub(/-[DH]$/,"",$7);print $7}' | xargs -n100 exim -Mrm;
}


function blacklist() {

        IP=$(hostname -i);
        MAILIPCHECK=$(grep -e "\*:" /etc/mailips | cut -f2 -d' ');
        if [[ -z $1 ]];then
                if [[  ! -z $(grep -s "tree.mfilter.dimenoc.com" /etc/exim.conf.local) ]];then
                        echo ""
                        echo "This server is on MFilter, check for MFilter blocks."
                        echo ""
                elif [[ -z $(grep -e "\*:" /etc/mailips | cut -f2 -d' ') ]];then
                        echo ""
                        echo "http://mxtoolbox.com/SuperTool.aspx?action=blacklist:"$IP""
                        echo "http://www.senderbase.org/lookup/?search_string="$IP""
                        echo ""
                else
                        echo ""
                        echo "http://mxtoolbox.com/SuperTool.aspx?action=blacklist:"$MAILIPCHECK""
                        echo "http://www.senderbase.org/lookup/?search_string="$MAILIPCHECK""
                        echo ""
                fi
        else
                echo ""
                echo "http://mxtoolbox.com/SuperTool.aspx?action=blacklist:"$1""
                echo "http://www.senderbase.org/lookup/?search_string="$1""
                echo ""
        fi
}

dnalookup() {
    if [ -z "$1" ];then
        echo "Usage: dnalookup USER"
        return
    fi
    if [ ! -d /home/"$1"/public_html ];then
        echo "User Account Not Found."
        return
    fi
        DOMAIN=$(grep $1 /etc/trueuserdomains | cut -f1 -d':');
        echo "https://admin.dimenoc.com/hosting/search/criteria/domain/query/$DOMAIN"
}
_dnalookup() {
    local cur
    cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $( compgen -f /var/cpanel/users/$cur | perl -pi -e 's/.*\/(.*)/$1/g' ) )
}
complete -o nospace -F _dnalookup dnalookup

restrict_http()
{
REASON=${REASON:-"${*}"}
: ${REASON:?No Reason Given}
chattr -ia .htaccess
mv --backup=numbered -T .htaccess .htaccess.orig &>/dev/null
cat <<neof > .htaccess
order deny,allow
deny from all
#=?ansi?B?VlBOIElQ?=
allow from 72.29.91.30
#=?ansi?B?VUNGIE9mZmljZQ==?=
allow from 72.29.91.42
#=?ansi?B?VUNGIE9mZmljZSBXZWIgRmlsdGVy?=
allow from 72.29.91.44
#=?ansi?B?SERVUyBOT0M=?=
allow from 67.23.232.178
#=?ansi?B?RFQgT2ZmaWNl?=
allow from 64.128.130.214
allow from 67.23.232.183
errordocument 403 "Temporarily closed for maintenance.
#" ~AlanR on $(date +'%F %T') for ${REASON}
neof
chattr +ia .htaccess
unset REASON
}

train_sa() {

    if [ -z "$1" ];then
        echo "Usage: train_sa USER"
        return
    fi

    su "$1" -s /bin/bash -c "sa-learn --dump magic"
    su "$1" -s /bin/bash -c "sa-learn --clear"
    su "$1" -s /bin/bash -c "sa-learn --sync"
    rm auto-whitelist 2> /dev/null

    echo "Please enter the email account with SPAM-TRAIN and HAM-TRAIN folders"
    read email

    USER=$(echo $email | cut -d'@' -f1)
    DOMAIN=$(echo $email | cut -d'@' -f2)

    if [[ ! -d /home/"$1"/mail/"$DOMAIN"/"$USER"/.SPAM-TRAIN || ! -d /home/"$1"/mail/"$DOMAIN"/"$USER"/.HAM-TRAIN ]];then
        echo "Could not find HAM-TRAIN or SPAM-TRAIN folders!"
        return
    fi

    echo -e "\nTraining with SPAM-TRAIN tokens:"
    su "$1" -s /bin/bash -c "sa-learn --progress --spam /home/$1/mail/$DOMAIN/$USER/.SPAM-TRAIN/cur"

    echo -e "\nTraining with HAM-TRAIN tokens:"
    su "$1" -s /bin/bash -c "sa-learn --progress --ham /home/$1/mail/$DOMAIN/$USER/.HAM-TRAIN/cur"

    sed -i '/use_auto_whitelist/d' /home/"$1"/.spamassassin/user_prefs
    sed -i '/URIBL_DBL_SPAM/d' /home/"$1"/.spamassassin/user_prefs
    sed -i '/URIBL_JP_SURBL/d' /home/"$1"/.spamassassin/user_prefs
    sed -i '/URIBL_WS_SURBL/d' /home/"$1"/.spamassassin/user_prefs

    echo "use_auto_whitelist 0" >> /home/"$1"/.spamassassin/user_prefs
    echo "URIBL_DBL_SPAM 6.0" >> /home/"$1"/.spamassassin/user_prefs
    echo "URIBL_JP_SURBL 4.0" >> /home/"$1"/.spamassassin/user_prefs
    echo "URIBL_WS_SURBL 4.0" >> /home/"$1"/.spamassassin/user_prefs
}


function findspammers() {
   wget -q legal.hostdime.com/alanr_env/test/findspammers.sh
   bash findspammers.sh;
   rm findspammers.sh -f
}

function emailpass() {
    wget -q http://legal.hostdime.com/alanr_env/emailpass.sh
    sh emailpass.sh $1;
    rm emailpass.sh -f
}

injectcleaner() {
    if [[ $(uname -o) =~ "Cygwin" ]];then
        wget -q http://legal.hostdime.com/andrewd_env/pyclean.py
        python pyclean.py
        rm pyclean.py -f
        return
    fi
    python <(curl -k -s http://legal.hostdime.com/andrewd_env/pyclean.py) "$@"
}

symrm()
{
find -type l; for LINK in `find -type l`; do readlink -e $LINK >> /root/active_links.txt; done; echo Identified Active Symlinks Recorded Here: /root/active_links.txt; find -type l -exec unlink {} \;
}

function savelogs { echo "archive-logs=1" > /home/$1/.cpanel-logs ; chown $1.$1 /home/$1/.cpanel-logs; };

conn() {

    bash <(curl -k -s https://scripts.dimenoc.com/files/netstat_one_liner_304.sh);

}



qnuke() {

    mv /var/spool/exim/input /var/spool/exim/input2;
    mv /var/spool/exim/msglog /var/spool/exim/msglog2;
    echo "Removing Input"
    rm -rf input2;
    echo "Removing Msglog"
    rm -rf msglog2;
    echo "Done!"

}


inodebreakdown() {
    find . -maxdepth 1 -type d | while read line ; do echo "$( find "$line"| wc -l) $line" ; done | sort -rn
}

owner() {
    if [ -z "$1" ];then
        echo "Usage: owner USER"
        return
    fi
    grep "$1" /etc/trueuserowners
}
complete -o nospace -F _www owner


pwn() {
    if [ -z "$1" ];then
        echo "Usage: pwn FILES"
        return
    fi
    until [ -z "$1" ];do
        chmod 000 "$1"
        chown 0:0 "$1"
        chattr +ai "$1"
        shift
    done
}


unpwn() {
    if [ -z "$1" ];then
        echo "Usage: unpwn FILES"
        return
    fi
    until [ -z "$1" ];do
        chattr -ai "$1"
        if [ -d "$1" ];then
            chmod 755 "$1"
        else
            chmod 644 "$1"
        fi
        chown `pwd | cut -d/ -f3`:`pwd | cut -d/ -f3` "$1"
        shift
    done
}

pwnmail() {
    if [ -z "$1" ]; then
        echo "Usage: pwnmail STRING"
        return
    fi

    if [ "$1" == "frozen" ];then
        exiqgrep -z -i | xargs exim -Mrm
        return
    fi

    exim -bp | grep -B1 "$1" | grep '<.*>' | awk '{print $3}' | while read line; do exim -Mrm $line; done
}

alias ag="${HOME}/ag --no-numbers"

ag_check() {

    if [ ! -f /root/parallel ];then
        wget -q http://legal.hostdime.com/parallel -O /root/parallel
        chmod 500 /root/parallel
    fi

    if [ -f "${HOME}/ag" ];then
        return
    fi

    if [[ $(uname -i) == "x86_64" ]];then
        wget -q http://legal.hostdime.com/ag_64 -O "${HOME}/ag"
    else
        wget -q http://legal.hostdime.com/ag_32 -O "${HOME}/ag"
    fi

    chmod 500 "${HOME}/ag"
}

qgrep() {

    local OPTIND
    local OPTARG
    while getopts ":plsc:" opt; do
        case $opt in
            p ) local NONULL='! -perm 000' ;;
            l ) local LFILES='-EHil' ;;
            s ) if [[ $(uname -o) =~ "Cygwin" ]];then local SHLLSRCH="c3284d|psbt|iframe.name.twitter.scrolling|mjdu|gdsg|filesman|system.file.do.not.delete|2e922c|r57shell|default_use_ajax|tryag_vb|priv8|pgems|@error_reporting\(0\)|0c0896|tress.x61|_REQUEST..........;.eval.........;.exit..;|yabod1|SEC-ADVISOR|.x65.x64|Hadidi44";else local SHLLSRCH="($(echo $(curl --silent http://legal.hostdime.com/andrewd_env/shell_patterns) | tr ' ' '|'))";fi;;
            c ) local SHLLSRCH="($OPTARG)";;
            : ) echo "-$OPTARG requires an argument";return 1;;
            \? ) echo "Usage: qgrep [-l (list files)] [-s (shells) ] [-p (no perm 000) ] [-c SEARCHSTR]"
                return 1;;
        esac
    done

    GREPARGS=${LFILES:-'-EHi'}
    ARGS1=${NONULL:-''}
    SEARCH=${SHLLSRCH:-"(gzinflate|base64_decode)"}
    find -type f $ARGS1 -regex ".*\.\(htm\|html\|shtml\|asp\|php\|inc\|tmp\|js\|htaccess\|pl\)" -print0 | xargs -0 grep $GREPARGS $SEARCH --color=always
    return 0
}

function chpass() { if [ "$2" == "" ]; then pass=`cat /dev/urandom| tr -dc 'a-zA-Z0-9' | head -c 12`; ALLOW_PASSWORD_CHANGE=1 /scripts/chpass "$1" "$pass"; mysql mysql -e "UPDATE user SET Password=password('$pass') WHERE User='$1'"; mysql mysql -e "flush privileges" ; echo -e "Password changed to $pass\n"; else ALLOW_PASSWORD_CHANGE=1 /scripts/chpass "$1" "$2"; mysql mysql -e "UPDATE user SET Password=password('$2') WHERE User='$1'"; mysql mysql -e "flush privileges" ; echo "Password changed to $2"; fi; /scripts/ftpupdate; }

www() {
    if [ -z "$1" ];then
        echo "Usage: www USER"
        return
    fi
    if [ ! -d /home/"$1"/public_html ];then
        echo "Public html directory for user $1 not found."
        return
    fi
    cd /home/"$1"/public_html
}

_www() {
    local cur
    cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $( compgen -f /var/cpanel/users/$cur | perl -pi -e 's/.*\/(.*)/$1/g' ) )
}

complete -o nospace -F _www www
complete -o nospace -F _www addspf
complete -o nospace -F _www dkim

addspf() {
    if [ -z "$1" ]; then
        echo "Usage: addspf USER"
        return
    fi
    /usr/local/cpanel/bin/spf_installer "$1" '' 1 1
    echo "Added SPF records for account $1"
}

dkim() { /usr/local/cpanel/bin/dkim_keys_install "$1"; }

qgrep_ag() {

    ag_check

    local OPTIND
    local OPTARG
    while getopts ":plsc:" opt; do
        case $opt in
            p ) local NONULL='! -perm 000' ;;
            l ) local LFILES='-il' ;;
            s ) local SHLLSRCH="($(echo $(curl --silent http://legal.hostdime.com/andrewd_env/shell_patterns) | tr ' ' '|'))";;
            c ) local SHLLSRCH="($OPTARG)";;
            : ) echo "-$OPTARG requires an argument";return 1;;
            \? ) echo "Usage: qgrep [-l (list files)] [-s (shells) ] [-p (no perm 000) ] [-c SEARCHSTR]"
                return 1;;
        esac
    done

    GREPARGS=${LFILES:-'-i'}
    ARGS1=${NONULL:-''}
    SEARCH=${SHLLSRCH:-"(gzinflate|base64_decode)"}
    find -type f $ARGS1 -regex ".*\.\(htm\|html\|shtml\|asp\|php\|inc\|tmp\|js\|htaccess\|pl\)" -print0 | xargs -0 "${HOME}/ag" --no-numbers --noheading $GREPARGS $SEARCH 2> /dev/null
    #find -type f $ARGS1 -regex ".*\.\(htm\|html\|shtml\|asp\|php\|inc\|tmp\|js\|htaccess\|pl\)" -print0 | /root/parallel -n 100 -j 4 -q0 "${HOME}/ag" --no-numbers --noheading $GREPARGS $SEARCH 2> /dev/null
    return 0
}

function checkapache() {
    if [[ `strings /usr/local/apache/bin/httpd | grep "UnhardenedSymLinks\|UnsecuredSymLinks"` != '' ]]; then
        echo -e "Apache \033[0;32mis patched\033[m\017 against SYMLINK attacks.";
    else echo -e "Apache is \033[0;31mNOT PATCHED\033[m\017 against SYMLINK attacks.";
    fi
}

cms() {
        wget -q http://legal.hostdime.com/alanr_env/cmspass.sh
        sh cmspass.sh $1
        rm -f cmspass.sh
}

sysinfo() {
        wget http://legal.hostdime.com/mikec_env/run/sys1.sh
        sh sys1.sh
        rm -f sys1.sh
}


updatemodsec() {
    if [ -f /usr/local/apache/conf/modsec2.conf ];then
        rm /usr/local/apache/conf/modsec2.conf -f
    fi

    wget --quiet http://legal.hostdime.com/modsec2.conf -O /usr/local/apache/conf/modsec2.conf
    chmod 600 /usr/local/apache/conf/modsec2.conf

    if [ -f /usr/local/apache/conf/modsec2.user.conf ];then
        rm /usr/local/apache/conf/modsec2.user.conf -f
    fi

    wget --quiet http://legal.hostdime.com/modsec2.user.conf -O /usr/local/apache/conf/modsec2.user.conf
    chmod 600 /usr/local/apache/conf/modsec2.user.conf


    if [ ! -f /usr/local/apache/conf/modsec2.custom.local.conf ];then
        touch /usr/local/apache/conf/modsec2.custom.local.conf
    fi


    if [ ! -f /etc/cron.daily/modsec_upd_new ];then
        wget --quiet http://legal.hostdime.com/modsec2_upd_new -O /etc/cron.daily/modsec2_upd_new
        chmod +x /etc/cron.daily/modsec2_upd_new
    fi

    service httpd configtest
    if [ $? -eq 0 ];then
        /scripts/restartsrv_httpd
    fi
}

ftpupload() {
        grep 'upload' /var/log/messages* | grep $1
}

cpanelupload() {
        grep $1 /usr/local/cpanel/logs/access_log | grep --color=auto -E '"(POST|GET) .*(xfercpanel|live_statfiles|live_fileop|passwd|upload-ajax|editit).* HTTP/[[:digit:].]+"'
}


function dcp { for i in `seq 1 7 `; do let i=$i+1 ; let  k=$i-1 ; let s="$(date +%s) - (k-1)*86400"; let t="$(date +%s) - (k-2)*86400"; echo `date -Idate -d "1970-01-01 $s sec"`; /usr/local/cpanel/bin/dcpumonview `date -d "1970-01-01 $s sec" +%s` `date -d "1970-01-01 $t sec" +%s` | sed -r -e 's@^<tr bgcolor=#[[:xdigit:]]+><td>(.*)</td><td>(.*)</td><td>(.*)</td><td>(.*)</td><td>(.*)</td></tr>$@Account: \1\tDomain: \2\tCPU: \3\tMem: \4\tMySQL: \5@' -e 's@^<tr><td>Top Process</td><td>(.*)</td><td colspan=3>(.*)</td></tr>$@\1 - \2@' |  grep "Domain: $2" -A3 ; done }
alias d7monview='dcp "$1"';

complete -o nospace -F _www d7monview

function domlogs { echo -ne "Log File:\t/usr/local/apache/domlogs/$1\n"; echo -ne "Log Start Time:\t"; head -n1 "/usr/local/apache/domlogs/$1" | sed -nr "s/.*(\[[^]]*\]).*/\1/p"; echo -ne "Log End Time: \t"; tail -n1 "/usr/local/apache/domlogs/$1" | sed -nr "s/.*(\[[^]]*\]).*/\1/p"; echo -ne "Total Hours:\t"; TOTALHOUR=$(echo "(`tail -n1 "/usr/local/apache/domlogs/$1" | awk 'BEGIN{ m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|"); for(o=1;o<=m;o++){ date[d[o]]=sprintf("%02d",o) } } { gsub(/\[/,"",$4); gsub(":","/",$4); gsub(/\]/,"",$5); n=split($4, DATE,"/"); day=DATE[1]; mth=DATE[2]; year=DATE[3]; hr=DATE[4]; min=DATE[5]; sec=DATE[6]; MKTIME= mktime(year" "date[mth]" "day" "hr" "min" "sec); print MKTIME }'`-`head -n1 "/usr/local/apache/domlogs/$1" | awk 'BEGIN{ m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|"); for(o=1;o<=m;o++){ date[d[o]]=sprintf("%02d",o) } } { gsub(/\[/,"",$4); gsub(":","/",$4); gsub(/\]/,"",$5); n=split($4, DATE,"/"); day=DATE[1]; mth=DATE[2]; year=DATE[3]; hr=DATE[4]; min=DATE[5]; sec=DATE[6]; MKTIME= mktime(year" "date[mth]" "day" "hr" "min" "sec); print MKTIME }'` ) / 3600" | bc -l | xargs printf "%1.2f"); echo $TOTALHOUR; echo -n "Total Raw Hits: "; TOTALRAW=`wc -l "/usr/local/apache/domlogs/$1" | awk '{print $1}'`; AVGPERHOUR=`echo "$TOTALRAW/$TOTALHOUR" | bc -l | xargs printf "%1.0f"`; echo "$TOTALRAW (Avg $AVGPERHOUR per hour)"; }

winpwn() {
 mv "$1" "/cygdrive/c/Users/Administrator/Desktop/bad_files/";
}

alias secureserver='wget legal.hostdime.com/secure.sh -O /root/secure.sh; screen -S server_secure sh /root/secure.sh'
alias mc="exim -bpc"
alias m="exim -bp"
alias vb='exim -Mvb'
alias vh='exim -Mvh'
alias vl='exim -Mvl'
alias ll='ls -lac'
alias chkmailabuse='less /var/log/exim_mainlog | grep sendmail | grep -vE "csf|FCron"'



alias awesome="echo 'Alan is Awesome! DUH!!!'"
                                                                                                                              446,1         Fim
