#!/bin/bash

echo "HISTCONTROL=ignorespace" >> ~/.bashrc
sed -i '$d' .bash_history
