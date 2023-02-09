#!/bin/bash

#set -x

#infile="conns.log"
infile="${1}"

# parsing the whole file can be horribly slow... skip to last dump of connection data
last_group=`grep -n '^#######' ${infile} | tail -n 1 | cut -d':' -f1`
total_lines=`cat ${infile} | wc -l`
lines=$(( 2 + total_lines - last_group ))

echo "----- ${lines} lines ---- tot: ${total_lines}, last: ${last_group}"

start_time=`head -n2 ${infile} | tail -n 1 | cut -d' ' -f2`
end_time=`tail -n ${lines} ${infile} | grep -A1 '###' | tail -n1 | cut -d' ' -f2`
elapsed_min=$(( (end_time - start_time) / 60 ))
end_time=$(date -d @`grep time ${infile} | tail -n 1 | cut -d' ' -f2`)

bw_data=`tail -n ${lines} ${infile} | awk '/^#/ {out=1} out{print}' | tr -s ' ' | cut -d' ' -f1,2,6 | tr -s ':' ' '| cut -d' ' -f1,3,5 | awk '/^[0-9]/ { a[$1" "$2]+=$3; c[$1" "$2]+=1 } END {for (i in a) print a[i], i, c[i]}'  | sort -n`
local_ip=`ifconfig | awk '/^[a-z]/ {x=$1} /[ \t]+inet/ {print $2, x}' | tr -d ':'`

get_ip() {
  res=`nslookup $1 | grep name | cut -d'=' -f2 | tr -d ' ' | sort -n | head -n 1 | tr -s '\n' ' '`
  while read x; do
    #echo "Checking $x" >&2
    i=`echo $x | cut -d' ' -f1`
    n=`echo $x | cut -d' ' -f2`
    if [[ "${i}" == "${1}" ]]; then
      res="$n"
    fi
  done < <(echo "${local_ip}")
  echo -n "${res}" | sed -e 's/.svc.cluster.local.//'
}

echo "${elapsed_min} minutes end_time: ${end_time}"

while read l; do
  b=`echo $l | cut -d' ' -f1`
  c=`echo $l | cut -d' ' -f2`
  s=`echo $l | cut -d' ' -f3`
  cn=`get_ip $c`
  sn=`get_ip $s`
  if [[ "${cn}" == "eth0" ]]; then
    rx=$((rx + b))
  fi
  if [[ "${sn}" == "eth0" ]]; then
    tx=$((tx + b))
  fi
  echo "$l -- ${cn} -- ${sn}"
done < <(echo "${bw_data}")

echo "Totals..." 
echo "${rx} rx"
echo "${tx} tx"

