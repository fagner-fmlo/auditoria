#!/bin/bash

###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.1								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

apachectl fullstatus | grep "http/1.1" | awk {'print $14'} | sort | uniq -c | sort -n | tail -5
cat /usr/local/apache/logs/access_log |  grep "http/1.1" | awk {'print $14'} | sort | uniq -c | sort -n | tail -5 | netstat -tunelap|egrep -v 'TIME_W|LIST'|awk '/:80|:443/{print $5}'|cut -d: -f1 | sort | uniq -c | sort -nk 1 | tail -20
