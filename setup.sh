#!/usr/bin/env bash

sudo apt install arptables dsniff arp-scan sqlite3

sqlite3 status.db -init dbschema.sql