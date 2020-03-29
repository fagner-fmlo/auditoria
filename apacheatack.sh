#!/bin/bash


###############################################################################
# Copyright 2020							                                                
# Author: Fagner Mendes							                                          
# License: GNU Public License						                                      
# Version: 1.6								                                                  
# Email: fagner.mendes22@gmail.com					                                  
###############################################################################

# This script check if Apache suffer atack via Syslink

#for usage of colors, please use the function of colors called "cores"

  # This function will make the script have colors, in some parts, that it will be important
  # Thanks to AlanV. from ConsultaLinux.org

  # COLORS CODES BEGUN #
  code="\033["
  endcode="\033[0m"

  # LETTER COLORS #
  reds="0;31m";greens="0;32m";browns="0;33m";blues="0;34m"
  purples="0;35m";cyans="0;36m";greylights="0;37m";redlights="1;31m"
  lightgreens="1;32m";yellows="1;33m";bluelights="1;34m";purplelights="1;35m";cyanlights="1;36m";whites="1;37m"

  # COLORS END #


  green() { echo -e "${code}${greens}$*${endcode}"; }
  lightgreen() { echo -e "${code}${lightgreens}$*${endcode}"; }
  brown() { echo -e "${code}${browns}$*${endcode}"; }
  blue() { echo -e "${code}${blues}$*${endcode}"; }
  bluelight() { echo -e "${code}${bluelights}$*${endcode}"; }
  purple() { echo -e "${code}${purples}$*${endcode}"; }
  purplelight() { echo -e "${code}${purplelights}$*${endcode}"; }
  cyan() { echo -e "${code}${cyans}$*${endcode}"; }
  cyanlight() { echo -e "${code}${cyanlights}$*${endcode}"; }
  greylight() { echo -e "${code}${greylights}$*${endcode}"; }
  red() { echo -e "${code}${reds}$*${endcode}"; }
  redlight() { echo -e "${code}${redlights}$*${endcode}"; }
  yellow() { echo -e "${code}${yellows}$*${endcode}"; }
  white() { echo -e "${code}${whites}$*${endcode}"; }


echo -e " \033[1;34m '''''''''   '      '''''''''   '       '  ' ' ' ' ' ''''''''' \033[0m "
echo -e " \033[1;34m '          ' '     '           ' '     '  '         '       ' \033[0m "
echo -e " \033[1;34m ''''''''' ' ' '    '   '''''   '   '   '  ' ' ' ' ' ''''''''' \033[0m "
echo -e " \033[1;34m '        '     '   '       '   '     ' '  '         '   '     \033[0m "
echo -e " \033[1;34m '       '       '  '''''''''   '       '  ' ' ' ' ' '       ' \033[0m "

{
    if [[ `strings /usr/local/apache/bin/httpd | grep "UnhardenedSymLinks\|UnsecuredSymLinks"` != '' ]]; then
        echo -e "Apache \033[0;32mis patched\033[m\017 against SYMLINK attacks.";
    else echo -e "Apache is \033[0;31mNOT PATCHED\033[m\017 against SYMLINK attacks.";
    fi
}
