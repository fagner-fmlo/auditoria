#!/bin/bash



echo -e "\nAnalisando os logs das contas, por gentileza aguarde.";
    sleep 1;

    xmlrpc=$(find /home/*/access-logs/ -type f | grep -v "ftp" | xargs grep "$(date '+%d/%b/%Y')" | grep "xmlrpc.php" | egrep -o "/home/\w+/" | sort | uniq -c | sort -n | tail -10);
    register=$(find /home/*/access-logs/ -type f | grep -v "ftp" | xargs grep "$(date '+%d/%b/%Y')" | grep "regist" | grep POST | egrep -o "/home/\w+/" | sort | uniq -c | sort -n | tail -10);
    register2=$(find /home/*/access-logs/ -type f | grep -v "ftp" | xargs grep "$(date '+%d/%b/%Y')" | grep "contato" | grep POST | egrep -o "/home/\w+/" | sort | uniq -c | sort -n | tail -10);

    echo -e "\n\t\txmlrpc"
    echo -e "-------------------------------------"
    echo -e "$xmlrpc"
    echo -e "-------------------------------------"

    echo -e "\n\tSistema de registro"
    echo -e "-------------------------------------"
    echo -e "$register"
    echo -e "-------------------------------------"

    echo -e "\n\tSistema de registro Joomla 07-2017"
    echo -e "-------------------------------------"
    echo -e "$register2"
    echo -e "-------------------------------------"

    echo -e "\n\tRequisiÃƒÂ§ÃƒÂµes POST"
    post=$(find /home/*/access-logs/ -type f | grep -v "ftp" | xargs grep "$(date '+%d/%b/%Y')" | grep POST | egrep -o "/home/\w+/" | sort | uniq -c | sort -n | tail -10);
    echo -e "-------------------------------------"
    echo -e "$post"
    echo -e "-------------------------------------"
    echo -e "\n\tRequisiÃƒÂ§ÃƒÂµes GET"
    get=$(find /home/*/access-logs/ -type f | grep -v "ftp" | xargs grep "$(date '+%d/%b/%Y')" | grep GET | egrep -o "/home/\w+/" | sort | uniq -c | sort -n | tail -10);
    echo -e "-------------------------------------"
    echo -e "$get"
    echo -e "-------------------------------------"

    echo -e "\n\tRequisiÃƒÂ§ÃƒÂµes na data de hoje"
    req=$(find /home/*/access-logs/ -type f | grep -v "ftp" | xargs grep "$(date '+%d/%b/%Y')" | egrep -o "/home/\w+/" | sort | uniq -c | sort -n | tail -10);
    echo -e "-------------------------------------"
    echo -e "$req"
    echo -e "-------------------------------------"
