#!/bin/bash

}
function brutekiller() {
        brutecheck | awk '{print $11}' | sort | uniq | while read ip;do csf -d $ip;done
}

