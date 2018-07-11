#!/usr/bin/env python
# TAKEN FROM http://code.activestate.com/recipes/52220-the-simplest-cgi-program
# This is my minimal cgi template.
# Another thing I do is wrap my entire script in a try block.
# It's also good to wrap the import statements, because
# sometimes these will raise exceptions too.
try:
  import traceback, sys, os, cgi
  # The following makes errors go to HTTP client's browser
  # instead of the server logs.
  sys.stderr = sys.stdout
  cgi.test()
except Exception, e:
  print 'Content-type: text/html\n'
  print
  print '&lt;html&gt;&lt;head&gt;&lt;title&gt;'
  print str(e)
  print '&lt;/title&gt;'
  print '&lt;/head&gt;&lt;body&gt;'
  print '&lt;h1&gt;TRACEBACK&lt;/h1&gt;'
  print '&lt;pre&gt;'
  traceback.print_exc()
  print '&lt;/pre&gt;'
  print '&lt;/body&gt;&lt;/html&gt;'