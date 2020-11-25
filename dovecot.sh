#!/bin/bash


###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.0								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.


#Dovecot reads from its index files when it displays emails in webmail. 
#The issue that webmail exhibits in this case may be caused by a corrupted Dovecot Index Cache. 
#To address this, you can remove the Dovecot Index files 

echo ""

echo "Inform the cP user"
read cpuser
/scripts/remove_dovecot_index_files --user $cpuser 
