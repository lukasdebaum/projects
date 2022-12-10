#!/usr/bin/env python3

import re
import subprocess

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


radius_stats = get_data()
if radius_stats:
    radius_stats = ",".join(("{}={}".format(*i) for i in radius_stats.items()))
    influx_pack = f"freeradius {radius_stats}"
    
    print(influx_pack)
