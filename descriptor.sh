#!/bin/bash

###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.0								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

#This is system monitor to analisy descriptors accounts in the server


echo "Inform the cpuser that you want analisys"
read cpuser
echo ""
echo "Starting analisy overall"

ps -U $cpuser | wc -l

echo ""
echo "Inform cpuser to this analisys"
read cpuser2
echo ""
echo "starting the comparison with the overall result"

su $cpuser2 -c "ulimit -u"
