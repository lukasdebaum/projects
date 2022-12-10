#!/usr/bin/env python3

import re
import subprocess
import snmp_passpersist

# snmpd.conf
# pass_persist .1.3.6.1.4.1.111111.100 /usr/local/sbin/freeradius_stats_snmp.py

ATTRIBUTES = {  "Auth-Responses" : "0.1", 
                "Auth-Duplicate-Requests" : "0.2", 
                "Auth-Malformed-Requests" : "0.3",
                "Auth-Invalid-Requests" : "0.4",
                "Auth-Dropped-Requests" : "0.5",
                "Auth-Unknown-Types" : "0.6",
                "Access-Requests" : "1.1",
                "Access-Accepts" : "1.2",
                "Access-Rejects" : "1.3",
                "Access-Challenges" : "1.4",
            }

HOST = "127.0.0.1"
PORT = 18121
SECRET = "xxx"

RADIUS_MSG = "Message-Authenticator = 0x00, FreeRADIUS-Statistics-Type = 1, Response-Packet-Type = Access-Accept"
RADCLIENT = "/usr/bin/radclient"
RETRIES = 1
TIMEOUT = 3

PARSER = re.compile(r'((?<=-)[AP][a-zA-Z-]+) = (\d+)')

def get_raw_data():
    process_echo = subprocess.Popen(["echo", RADIUS_MSG], stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False)
    radclient = f"{RADCLIENT} -r {RETRIES} -t {TIMEOUT} -x {HOST}:{PORT} status {SECRET}".split()
    process_rad = subprocess.Popen(radclient, stdin=process_echo.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False)

    process_echo.stdout.close()
    raw_result = process_rad.communicate()[0]

    if process_rad.returncode == 0:
        return raw_result.decode()

    return False

def get_data():
    result = get_raw_data()

    if not result:
        return False

    stats = dict()
    for key, value in PARSER.findall(result):
        stats[key] = value

    return stats

def update():
    radius_stats = get_data()

    for attribut in ATTRIBUTES:
        if attribut in radius_stats:
            pp.add_cnt_32bit(ATTRIBUTES[attribut], radius_stats[attribut], attribut)
        

#
pp = snmp_passpersist.PassPersist(".1.3.6.1.4.1.111111.100")
pp.start(update, 58)
