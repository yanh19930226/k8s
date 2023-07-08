#!/bin/bash
#
contact='root@wangxiaochun.com'
notify() {
    mailsubject="$(hostname) to be $1, vip floating"
    mailbody="$(date +'%F %T'): vrrp transition, $(hostname) changed to be $1"
    echo "$mailbody" | mail -s "$mailsubject" $contact
}
case $1 in
master)
    notify master
    ;;
backup)
    notify backup
    ;;
fault)
    notify fault
    ;;
*)
    echo "Usage: $(basename $0) {master|backup|fault}"
    exit 1
    ;;
esac