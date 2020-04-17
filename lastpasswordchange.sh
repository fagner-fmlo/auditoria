#!/usr/bin/bash

###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.0								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

echo ""

#This script accurately checks if the password was changed

echo "Inform the cpuser"
read cpuser
chage -l $cpuser

