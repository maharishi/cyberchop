#!/usr/bin/env python

import traceback, sys, os, cgi, subprocess, sqlite3, json

def getDatabase():
    conn = sqlite3.connect('status.db')
    return conn

def getCursor(conn):
    conn.row_factory = sqlite3.Row
    return conn.cursor()

def flush(form):
    p=subprocess.Popen(['sudo','/var/www/html/cyberchop/cgi-bin/cyberchop.sh','-f'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "flushed"

def scan(form):
    p=subprocess.Popen(['sudo', '/var/www/html/cyberchop/cgi-bin/cyberchop.sh','-s'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "scanned"

def resumeall(form):
    p=subprocess.Popen(['sudo','/var/www/html/cyberchop/cgi-bin/cyberchop.sh','-a'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "resumedall"

def enable(form):
    rowid=form.getfirst("rowid", 0)
    p=subprocess.Popen(['sudo','/var/www/html/cyberchop/cgi-bin/cyberchop.sh','-c', rowid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "enabled"

def disable(form):
    rowid=form.getfirst("rowid", 0)
    p=subprocess.Popen(['sudo','/var/www/html/cyberchop/cgi-bin/cyberchop.sh','-r', rowid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err =  p.communicate()
    default(form, err)
    # print "disabled"

def friendly(form):
    friendlynameitems=[]
    conn = getDatabase()
    rowid=form.getfirst("rowid", None)
    name=form.getfirst("name", None)
    if(rowid is not None and name is not None):
        selectsql = '''
            SELECT ml.mac_address, ml.ip_address, md.friendly_name 
            FROM machine_list AS ml LEFT OUTER JOIN machine_details AS md 
                ON md.mac_address = ml.mac_address
            WHERE ml.rowid = ? OR ml.ip_address = ?;
        '''
        for row in getCursor(conn).execute(selectsql, (rowid, rowid)):
            if(row['friendly_name'] is None):
                insertsql = ''' 
                    INSERT INTO machine_details (mac_address, friendly_name) 
                    VALUES (?, ?);
                '''
                with conn:
                    conn.execute(insertsql, (row['mac_address'], name))
            else:
                updatesql = ''' 
                    UPDATE machine_details 
                    SET friendly_name = ? 
                    WHERE mac_address = ?;
                '''
                with conn:
                    conn.execute(updatesql, (name, row['mac_address']))
    for row in getCursor(conn).execute("SELECT ml.rowid, ml.ip_address, md.friendly_name FROM machine_list AS ml LEFT  OUTER JOIN machine_details AS md ON md.mac_address = ml.mac_address"):
        friendlynameitems.append({'rowid': row['rowid'], 'ip_address': row['ip_address'], 'friendly_name': row['friendly_name']})
    conn.close()
    response={ "friendlist": friendlynameitems, "error":"" }
    print(json.JSONEncoder().encode(response))

def default(form, log=""):
    selectsql = '''
            SELECT ml.rowid, ml.ip_address, md.friendly_name 
            FROM machine_list AS ml LEFT OUTER JOIN machine_details AS md 
                ON md.mac_address = ml.mac_address
            WHERE ml.active = ?;
        '''
    c = getCursor(getDatabase())
    disableditems=[]
    enableditems=[]
    for row in c.execute(selectsql, ( '0' )):
        disableditems.append({'name':row['ip_address'], 'friendly_name': row['friendly_name'], "rowid": row['rowid']})
    for row in c.execute(selectsql, ( '1' )):
        enableditems.append({'name':row['ip_address'], 'friendly_name': row['friendly_name'], "rowid": row['rowid']})
    c.close()
    response={ "disableditems": disableditems, "enableditems": enableditems, "error":log}
    print(json.JSONEncoder().encode(response))

switcher = {
        "flush": flush,
        "scan": scan,
        "resumeall": resumeall,
        "enable": enable,
        "disable": disable,
        "friendly": friendly,
        "default": default,
    }

def main():
    form = cgi.FieldStorage()
    func = switcher.get(form.getfirst("action","default"), default)
    func(form)

if __name__ == "__main__":
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