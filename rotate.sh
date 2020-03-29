#!/usr/bin/env bash
#ajustar alguns checks na opção ip

clean() {
  #remove temp files
rm -rf /tmp/newlist.txt && echo -e "$green >> $blue Temp files was been excluded" || echo -e "$red >> $blue Something strange was happened"
}

clean

#### main ####
main() {

  [ $# -ne 1 ] && error "Please specify a FQDN or IP as a parameter."

  fqdn=$(echo $1 | grep -P "(?=^.{5,254}$)(^(?:(?!\d+\.)[a-za-z0-9_\-]{1,63}\.?)+(?:[a-za-z]{2,})$)")

  if [[ $fqdn ]] ; then

    echo "You entered a domain: $1"

    domain=$(host $1 | head -n1 | awk '{print $4}')

    reverseit $domain "IP not valid or domain could not be resolved."
  else

    echo "Checking If the ip random is listed: $1"
    reverseit $1 "IP not valid."
  fi

  loopthroughblacklists $1
}

#### reverseit ####
reverseit() {

  reverse=$(echo $1 |
  sed -ne "s~^\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)$~\4.\3.\2.\1~p")

  if [ "x${reverse}" = "x" ] ; then

    error $2 
    exit 1
  fi
}

#### loopthroughblacklists ####
loopthroughblacklists() {

  reverse_dns=$(dig +short -x $1)

  echo $1 name ${reverse_dns:----}

  for bl in ${blacklists} ; do

      printf $(env tz=utc date "+%y-%m-%d_%h:%m:%s_%z")
      printf "%-40s" " ${reverse}.${bl}."

      listed="$(dig +short -t a ${reverse}.${bl}.)"

      if [[ $listed ]]; then

        if [[ $listed == *"timed out"* ]]; then

          echo "[timed out]"
        else
        
          echo "[blacklisted] (${listed})" 
        fi
      else

          echo "[not listed]"
      fi
  done
}

#### error ####
error() {

  echo $0 error: $1 >&2
  exit 2
}


#list blacklist collected from some sources by IgorA on 22/08/2019
blacklists="
aspews.ext.sorbs.net
b.barracudacentral.org
bb.barracudacentral.org
block.dnsbl.sorbs.net
bl.score.senderscore.com
bl.spamcop.net
cbl.abuseat.org
cbl.anti-spam.org.cn
cblless.anti-spam.org.cn
cblplus.anti-spam.org.cn
dnsbl.sorbs.net
dnsbl.spfbl.net
http.dnsbl.sorbs.net
l1.bbfh.ext.sorbs.net
l2.bbfh.ext.sorbs.net
l4.bbfh.ext.sorbs.net
misc.dnsbl.sorbs.net
new.spam.dnsbl.sorbs.net
old.spam.dnsbl.sorbs.net
pbl.spamhaus.org
problems.dnsbl.sorbs.net
proxies.dnsbl.sorbs.net
recent.spam.dnsbl.sorbs.net
relays.dnsbl.sorbs.net
safe.dnsbl.sorbs.net
sbl.spamhaus.org
smtp.dnsbl.sorbs.net
socks.dnsbl.sorbs.net
spam.dnsbl.sorbs.net
talosintelligence.com
truncate.gbudb.net
web.dnsbl.sorbs.net
xbl.spamhaus.org
zen.spamhaus.org
zombie.dnsbl.sorbs.net
cbl.abuseat.org
dnsbl.sorbs.net
bl.spamcop.net
zen.spamhaus.org
dnsbl.spfbl.net
csi.cloudmark.com
"

# constant/global vars
currentip=$(cat /etc/exim.conf | grep 'interface' | egrep -o "(((1[0-9]|[1-9]?)[0-9]|2([0-4][0-9]|5[0-5]))\.){3}((1[0-9]|[1-9]?)[0-9]|2([0-4][0-9]|5[0-5]))" | head -n 1);



#Colors
green="\033[01;32m"
blue="\033[01;34m"
red="\033[01;31m"
white="\033[01;37m"
pink="\033[01;35m"

#varpath
path=/etc/exim.conf

#get main ip from the server
mainip=$(hostname -i);

#the all the ips from the server
ipssz+=($(for gg in `whmapi1 listips | grep ip: | egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | uniq | sort | egrep -v $mainip` ; do dig +short -x $gg | egrep -v "(static|NXDOMAIN)" ; if [ $? -eq 0 ] ; then echo "$gg"  ; fi ; done | grep -Pv "\b((?=[a-z0-9-]{1,63}\.)[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}\b"| egrep -v "[a-Z]+"));

#the array list was been created
ips=$(echo "${ipssz[*]}"| xargs -n1);


#actions that are necessary when start script
chattr -ia ${path}

#check the current ip for later, remove it from the list
  if [ -z $currentip ] ; then
    echo -e "$green>>$blue Exim conf file was with default configuration, without personalization of outgoing mailIP"
    currentip=${mainip}
  fi

#write on file temp
echo "$ips" |grep -v $currentip > /tmp/newlist.txt

#shuffle ips
ipsshuf=$(shuf -n 1 /tmp/newlist.txt);



rotate () {
#write on exim.conf
sed -i 's/interface =.*/interface = '${ipsshuf}'/g' ${path} && echo -e "$green >> $blue The IP was changed" || echo -e "$red >> $blue Error when try change IP"

#Now adjust the reverse IP
newip=$(cat /etc/exim.conf | grep 'interface' | egrep -o "(((1[0-9]|[1-9]?)[0-9]|2([0-4][0-9]|5[0-5]))\.){3}((1[0-9]|[1-9]?)[0-9]|2([0-4][0-9]|5[0-5]))" | head -n 1)
rev=$(host $newip | egrep -o " .*\.$" | grep -Po "\b((?=[a-z0-9-]{1,63}\.)[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}\b")

sed -i 's/helo_data =.*/helo_data = '${rev}'/g' ${path} && echo -e "$green >> $blue The HELO was been adjusted" || echo -e "$red >> $blue error when tried adjust the HELO"

#Now adjust the SPF and dkim only for localdomains
localdomains=$(for i in $(cat /etc/localdomains | grep -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$") ; do egrep $i /etc/trueuserdomains ; done | awk {'print $2'}) 
currentip2=$(cat /etc/exim.conf | grep 'interface' | egrep -o "(((1[0-9]|[1-9]?)[0-9]|2([0-4][0-9]|5[0-5]))\.){3}((1[0-9]|[1-9]?)[0-9]|2([0-4][0-9]|5[0-5]))" | head -n 1);
for locals in `echo $localdomains | xargs -n 1`; do 
        /usr/local/cpanel/bin/spf_uninstaller $locals 
        echo -e "$green >> $blue SPF was erased, now we are installing a default spf acording your new ip for: $white $locals $blue"
        /usr/local/cpanel/bin/spf_installer $locals +ip4:${currentip2},+ip4:${mainip} complete=1 overwrite=1 preserve=0 > /dev/null 2>&1 
        echo -e "$green >> $blueSPF adjusted for $white $locals - $pink Greetz to $blue Abuse&SecurityBR" 
        /usr/local/cpanel/bin/dkim_keys_install $locals > /dev/null 2>&1 
done
        echo -e " $red Finished. any issue? Let us know igor.a@hostdime.com.br"
}



case $1 in

--manual)
#the ip that will be used
while true ; do

main ${ipsshuf}
echo -e "$green>> $blue The ip that will be used is: $white ${ipsshuf}"
echo -e "Type (yes|No)"
read asnwer
if [[ "$asnwer" == "yes" ]] ; then
  echo -e "The ip was choiced and the script will continue adjusting IP: $white $ipuses"
  rotate
  clean
  break
else
  echo -e "$red >> You have typed no, or something takes the default asnwer, Leaving..."
  exit;
fi

done
;;

--auto)

;;

--ip)
ippass=$2
ipsshuf=${ippass}

if [ -z "$2" ]; then
  echo "Invalid Usage, null value"
  return;
fi
while true ; do
main $ippass
echo -e "$green>> $blue The ip that will be used is: $white ${ipsshuf}"
echo -e "Type (yes|No)"
read asnwer
if [[ "$asnwer" == "yes" ]] ; then
  rotate
  clean
  break
else
   echo -e "$red >> Leaving..."
  exit;
fi
done
;;

*)
echo "Invalid Option"
exit
;;

esac
