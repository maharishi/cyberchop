#!/usr/bin/env python

import traceback, sys, os, cgi, subprocess, sqlite3, json
def flush(form):
    p=subprocess.Popen(['sudo','/var/www/html/netcut/cgi-bin/netcut.sh','-f'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "flushed"

def scan(form):
    p=subprocess.Popen(['sudo', '/var/www/html/netcut/cgi-bin/netcut.sh','-s'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "scanned"

def resumeall(form):
    p=subprocess.Popen(['sudo','/var/www/html/netcut/cgi-bin/netcut.sh','-a'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "resumedall"

def enable(form):
    rowid=form.getfirst("rowid", 0)
    p=subprocess.Popen(['sudo','/var/www/html/netcut/cgi-bin/netcut.sh','-c', rowid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    print "enabled"

def disable(form):
    rowid=form.getfirst("rowid", 0)
    p=subprocess.Popen(['sudo','/var/www/html/netcut/cgi-bin/netcut.sh','-r', rowid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    print "disabled"

def default(form, log=""):
    conn = sqlite3.connect('status.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    disableditems=[]
    enableditems=[]
    for row in c.execute('SELECT rowid, ip_address FROM machine_list where active = 0'):
        disableditems.append({'name':row['ip_address'], "rowid": row['rowid']})
    for row in c.execute('SELECT rowid, ip_address FROM machine_list where active = 1'):
        enableditems.append({'name':row['ip_address'], "rowid": row['rowid']})
    response={ "disableditems": disableditems, "enableditems": enableditems, "error":log}
    print(json.JSONEncoder().encode(response))

switcher = {
        "flush": flush,
        "scan": scan,
        "resumeall": resumeall,
        "enable": enable,
        "disable": disable,
        "default": default
    }

def main():
    form = cgi.FieldStorage()
    func = switcher.get(form.getfirst("action","default"), default)
    func(form)
    
try:  
  print("Content-Type: application/json\n\n")
  # The following makes errors go to HTTP client's browser
  # instead of the server logs.
  sys.stderr = sys.stdout
  main()  
except Exception, e:
  print 'Content-Type: application/json'
  response=[{'error':str(e),'trace': traceback.print_exc()}]
  print(json.JSONEncoder().encode(response))