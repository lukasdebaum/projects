# freeradius

## disconnect_user.pl

Send Disconnect-Request (based on username) to multiple routers when the radius Server received an Accounting-Off Request based on the sending NAS client  
  
For Performance Reason use freeradius rlm_perl and not exec radiusclient  
https://wiki.freeradius.org/modules/rlm_perl

## freeradius_stats_snmp.py

Get freeradius Statistics for snmpd 

snmpd.conf
```
pass_persist .1.3.6.1.4.1.111111.100 /usr/local/sbin/freeradius_stats_snmp.py
```

## freeradius_stats.py

Get freeradius Statistics for telegraf

telegraf.d/freeradius.conf
```
[[inputs.exec]]
    commands = ["/usr/local/sbin/freeradius_stats.py"]
    timeout = "5s"
    data_format = "influx"
```
