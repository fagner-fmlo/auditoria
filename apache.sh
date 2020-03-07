#!/bin/bash

###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.0								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

apachectl fullstatus | grep "http/1.1" | awk {'print $14'} | sort | uniq -c | sort -n | tail -5
