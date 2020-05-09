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
echo "inform the domain"
read domain
uapi --user=$cpuser EmailAuth validate_current_spfs domain=$domain
