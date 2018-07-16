#!/usr/bin/env bash

sudo apt update

sudo apt install lighttpd python libsqlite3-dev

if [ ! -e /etc/lighttpd/conf-enabled/10-cgi.conf ]; then
    sudo lighttpd-enable-mod cgi
fi

sudo service lighttpd force-reload
sudo service lighttpd restart

sudo ln -s "$(pwd)"/netcut.sh ./html/cgi-bin/netcut.sh
sudo ln -s "$(pwd)"/html /var/www/html/netcut

sudo chgrp -R www-data "$(pwd)"/html
sudo chgrp -R www-data /var/log/lighttpd
sudo chmod -R 750 "$(pwd)"/html

sudo cp /etc/sudoers /etc/sudoers.bak
echo "www-data ALL=NOPASSWD: /var/www/html/netcut/cgi-bin/netcut.sh" | sudo tee -a /etc/sudoers > /dev/null

read -r -d '' conf << EOM
server.modules = (
        "mod_access",
        "mod_alias",
        "mod_compress",
        "mod_redirect",
        "mod_cgi",
        "mod_rewrite",
)

server.document-root        = "/var/www/html"
server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
server.errorlog             = "/var/log/lighttpd/error.log"
server.pid-file             = "/var/run/lighttpd.pid"
server.username             = "www-data"
server.groupname            = "www-data"
server.port                 = 80


index-file.names            = ( "index.php", "index.html", "index.lighttpd.html" )
url.access-deny             = ( "~", ".inc" )
static-file.exclude-extensions = ( ".php", ".pl", ".fcgi", ".py" )

compress.cache-dir          = "/var/cache/lighttpd/compress/"
compress.filetype           = ( "application/javascript", "text/css", "text/html", "text/plain" )

# default listening port for IPv6 falls back to the IPv4 port
## Use ipv6 if available
#include_shell "/usr/share/lighttpd/use-ipv6.pl " + server.port
include_shell "/usr/share/lighttpd/create-mime.assign.pl"
include_shell "/usr/share/lighttpd/include-conf-enabled.pl"

EOM

read -r -d '' cgiconf << EOM
# /usr/share/doc/lighttpd/cgi.txt

server.modules += ( "mod_cgi" )

\$HTTP["url"] =~ "/cgi-bin/" {
        cgi.assign = (
                ".py"  => "/usr/bin/python",
        )
}


EOM

sudo cp /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd_copy.conf
echo "$conf" | sudo tee /etc/lighttpd/lighttpd.conf

sudo cp /etc/lighttpd/conf-available/10-cgi.conf /etc/lighttpd/conf-available/10-cgi_copy.conf
echo "$cgiconf" | sudo tee /etc/lighttpd/conf-available/10-cgi.conf

sudo service lighttpd force-reload
sudo service lighttpd restart
