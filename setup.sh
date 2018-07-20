#!/usr/bin/env bash

sudo apt update

sudo apt install arptables dsniff arp-scan sqlite3

sudo arptables -F

sqlite3 bin/status.db -init dbschema.sql ".quit"

ln -s "$(pwd)"/bin/status.db ./html/cgi-bin/status.db