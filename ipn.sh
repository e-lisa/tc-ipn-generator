#!/usr/bin/env bash

# TrustCommerce IPN generator
# This script generates a TrustCommerece CSV report via a POST request
# and then loops though the results and contacts CiviCRM to submit IPN
# requests. This script exists because TrustCommerce does not currently
# support sending IPNs.
#
# Author: Lisa Marie Maginnis, Sr SysAdmin
# Copyright: Free Software Foundation 2014

# Load out configs
. $HOME/etc/ipn.conf.sh

# Get todays report
curl -s "$vault_url?custid=$USER&password=$PASS&querytype=transaction&begindate="$(date '+%m-%d-%Y') > $datafile 

# Flip date for consitancy (TC changes this)
sed 's/\([0-9][0-9]\)-\([0-9][0-9]\)-\([0-9][0-9][0-9][0-9]\)/\3-\1-\2/g' -i $datafile

# Loop though today's IPNs (this is an embedded awk script that generates our query string)
for link in `awk -F, '
/payment/{
   if($36!="") {
      
      date=$4
      sub(/[[:blank:]].*/,"",date);
      sub(/"/,"",date);
      tid=$5;
      bid=$36;
      amount=$7/100;

      if($13 == "approved") {
         status=1;

      } else if($13 == "decline") { 
         status=4;
      }

      checks=sprintf("%s%s%s%s", bid, tid, amount, date);
      command="printf \"%s\" \"" checks "\" | md5sum";
      command | getline data;
      close(command);
      sub(/[[:blank:]].*/,"",data);
      printf("'$civicrm_url'?reset=1&billingid=%s&amount=%s&trxn_id=%s&date=%s&status=%s&checksum=%s&key=meh&module=contribute\n", bid, amount, tid, date, status, data);
   }
}' $datafile`; do 
    
    # Process IPN URL and log it
    echo "Running: $link" >> $logfile
    curl -s $link >> $logfile
 done
