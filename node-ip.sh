#!/bin/bash
#
# Script for wireguard/batman gateways of Freifunk Muenchen to display the IP address of a connected node.
#
# node-ip.sh <fe80-address from map.ffmuc.net> <segment>
#

umask 022

PATH="/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin"

usage() {
        echo
        echo "$0: Utility to display connecting node IP address on FFMuc batman/wireguard gateways"
        echo
        echo "  $0 [options] [IPv6] [segment]"
        echo
        echo "  Options:"
        echo "    -v | --verbose                      Verbose mode"
        echo
        echo "  IPv6:"
        echo "    fe80 address of node from map.ffmuc.net"
        echo
        echo "  segment: one of"
        echo "    muc_cty, muc_nord, muc_ost, muc_sued, muc_west, uml_nord,"
        echo "    uml_ost, uml_sued, uml_west, gauting, freising, welt"
        echo

        exit 1
}


# check number of paramters
if [ $# -lt 2 -o $# -gt 3 ]; then
        usage
fi

if [ $1 = "-v" -o $1 = "--verbose" ]; then
        VERBOSE=true
        shift
fi

NodeIPv6_1="$1"
# check if node ip starts with fe80
if [ "${NodeIPv6_1:0:5}" != "fe80:" ]; then
        echo "Error: ipv6 $NodeIPv6_1 is not valid"
        usage
fi

domain="$2"
[ $VERBOSE ] && echo domain = $domain
# check if domain/segment is known
shopt -s extglob
case $domain in !(muc_cty|muc_nord|muc_ost|muc_sued|muc_west|uml_nord|\
        uml_ost|uml_sued|uml_west|gauting|freising|welt ))
        echo "Error: segment $domain not known"
        usage
esac

# one time ping so batman gets notified about a node address
ping6 -c1 $NodeIPv6_1%br-$domain >/dev/null 2>/dev/null

# get first MAC address
STRING1=$(batctl meshif bat-$domain ping -c1 $NodeIPv6_1%br-$domain | head -n1)
[ $VERBOSE ] && echo STRING1 = $STRING1

# at which position is the first open bracket
POS1=$(expr index "$STRING1" "\(")
[ $VERBOSE ] && echo POS1 = $POS1

# extract MAC address from answer
MAC1=${STRING1:$POS1:17}
[ $VERBOSE ] && echo MAC1 = $MAC1

# get second MAC address
STRING2=$(batctl meshif bat-$domain o | grep ${MAC1} | grep "^ \* ")
[ $VERBOSE ] && echo STRING2 = "$STRING2"

# get MAC addrees from 6th word
MAC2=`echo "$STRING2" | awk -v N=6 '{print $N}'`
[ $VERBOSE ] && echo MAC2 = $MAC2

# lookup IP address
STRING3="`bridge fdb show | grep $MAC2`"
[ $VERBOSE ] && echo STRING3 = $STRING3

# get IP address from 5th word
NodeIPv6_2=`echo "$STRING3" | awk -v N=5 '{print $N}'`
[ $VERBOSE ] && echo NodeIPv6_2 = $NodeIPv6_2

# lookup node ip adress
if [ -d /sys/devices/virtual/net/wg-$domain ]; then
        STRING4=`wg show wg-$domain | grep -C3 $NodeIPv6_2 |grep endpoint`
        [ $VERBOSE ] && echo STRING4 = $STRING4
elif [ -d /sys/devices/virtual/net/wg-uplink ]; then
        STRING4=`wg show wg-uplink | grep -C3 $NodeIPv6_2 |grep endpoint`
        [ $VERBOSE ] && echo STRING4 = $STRING4
else
        echo "wireguard interface not found"
fi

# get node IP from 2nd word
STRING5=`echo "$STRING4" | awk -v N=2 '{print $N}'`
[ $VERBOSE ] && echo STRING5 = $STRING5

# cut port address from answer
POS2=${STRING5%:*}
[ $VERBOSE ] && echo POS2 = ${#POS2}
STRING6="${STRING5:0:${#POS2}}"
echo Node IP = $STRING6

exit 0
