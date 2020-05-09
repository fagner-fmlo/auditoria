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
uapi --user=cpuser LastLogin get_last_or_current_logged_in_ip
