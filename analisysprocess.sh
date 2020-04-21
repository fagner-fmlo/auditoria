#!/bin/bash

###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.0								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

#This is system monitor process and serves to monitor the load of each process for a given service in the system

ps aux

echo "Inform the number PID that you want analisys"
read pid

echo "Inform the number in seconds to this analisy"
read seconds

pidstat -p $pid $seconds
