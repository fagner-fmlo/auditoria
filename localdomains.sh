#/bin/bash



cut -f 1,5 -d : /etc/localdomains| sed '1d' >> /root/named.txt
DOM=$( cat named.txt )

for i in $DOM; do dig -t TXT $i +short
done
