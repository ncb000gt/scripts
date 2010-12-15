import httplib, urlparse, sys, threading, difflib

class Fetcher(threading.Thread):

    def fetch(self, url, method="GET"):
        parsed = urlparse.urlparse(url)
        host = parsed.netloc
        uri = parsed.path
        http = httplib.HTTPConnection(host)
        if uri != None:
            http.request(method, uri)
            return http.getresponse().read()

    def run(self):
        self.page = self.fetch(sys.argv[1])
        i = 0
        while True:
            i += 1
            newpage = self.fetch(sys.argv[1])
            if newpage != self.page:
                for line in difflib.unified_diff(self.page.splitlines(1), newpage.splitlines(1)):
                    sys.stdout.write(line)
                                               
                print "---- pages were different after %i requests ----" % (i)
                exit(1)

if len(sys.argv) < 2:
    print "usage: python %s [url]" % sys.argv[0]
else:
    for i in xrange(20):
        Fetcher().start()
