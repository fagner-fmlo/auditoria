#!/bin/bash

###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.0								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

echo ""

echo "Inform the cpuser"
read cpuser
cd /home/$cpuser/public_html/
wget https://raw.githubusercontent.com/fagner-fmlo/arquivos/master/info.php
user=$(pwd | cut -d/ -f3)
find /home/$user -type f -exec chown $user.$user {} +
echo "Press <Enter> To continue and delete the file info.php"
read
rm -f info.php
echo -e "\033[01;35mSay Hello to Brazil"
