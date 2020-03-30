#!/usr/bin/env python

import urllib
import urllib2
import re
import sys
import signal
import struct
import socket
import array
import fcntl
import optparse
import HTMLParser
import csv
#import yum
try:
    from netaddr import *
except ImportError:
    print 'Install the python netaddr module with "easy_install netaddr" for CIDR checking features!'

def install_pkg(package):
    yb = yum.YumBase()
    yb.install(name=package)
    yb.resolveDeps()
    cback = yum.callbacks.ProcessTransNoOutputCallback()
    rback = yum.rpmtrans.NoOutputCallBack()
    yb.processTransaction(callback=cback, rpmDisplay=rback)


parser = optparse.OptionParser(usage="rbl-check [options] [IP-Address]")
parser.add_option('-a', '--all', help="check all interface IPs", default=False,
                    dest='all_ips', action='store_true')
parser.add_option('-p', help='Check ProofPoint reputation', action='store_true', 
                    default=False, dest='check_proofpoint')
parser.add_option('-s', help='Check SenderBase reputation', action='store_true',
                    default=False, dest='check_senderbase')
parser.add_option('-m', help='Check Microsoft reputation', action='store_true',
                    default=False, dest='check_microsoft')
parser.add_option('-t', help='Check TrendMicro reputation', action='store_true',
                    default=False, dest='check_trendmicro')
parser.add_option('--att', help='Check AT&T RBL for the main IP only', action='store_true',
                    default=False, dest='check_att')
parser.add_option('--verizon', help='Check Verizon RBL for the main IP only', action='store_true',
                    default=False, dest='check_verizon')
parser.add_option('--symantec', help='Check Symantec reputation', action='store_true',
                    default=False, dest='check_symantec')
parser.add_option('-f', '--full-rbls', help='Check all recommended RBLs', action='store_true',
                    default=False, dest='check_all_rbls')
parser.add_option('-c', '--custom-dnsrbl', help='Check only the specified DNSRBL', dest='dnsrbl',
                    type='string')
parser.add_option('-l', '--list-dnsrbls', help='List all major DNSRBLs', action='store_true',
                    default=False, dest='list_rbls')
parser.add_option('--senderscore', help='Check the SenderScore reputation', action='store_true',
                    default=False, dest='check_senderscore')

(opts, args) = parser.parse_args()

# get all interface IPs
# http://code.activestate.com/recipes/439093-get-names-of-all-up-network-interfaces-linux-only/
def getIPs():
    struct_size = 40
    if 8*struct.calcsize('P') == 32:
        struct_size -= 8

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    max_possible = 8

    while True:
        bytes = max_possible * struct_size
        names = array.array('B', '\0' * bytes)
        outbytes = struct.unpack('iL', fcntl.ioctl(s.fileno(), 0x8912,
            struct.pack('iL', bytes, names.buffer_info()[0])))[0]
        if outbytes == bytes:
            max_possible *= 2
        else:
            break

    namestr = names.tostring()

    IPtuples = [(namestr[i:i+16].split('\0',1)[0],socket.inet_ntoa(
                    namestr[i+20:i+24])) for i in range(0, outbytes, struct_size)]

    ips = [ x[1] for x in IPtuples if not '127.0.0' in x[1] and not '192.168.' in x[1] ]

    return ips

def symantec(IP):
    request = urllib2.Request('http://www.symantec.com/s/wl-brightmail/ip/' + IP + '.json')
    regex = re.compile('.rep.\ \:\ .(\w+).', re.MULTILINE|re.DOTALL)
    opener = urllib2.build_opener(urllib2.HTTPHandler)
    try:
        url = opener.open(request)
        data = url.read()
    except urllib2.URLError, e:
        print "Symantec rejected for reason: " + str(e.code)
        return

    r = regex.search(data)
    match = None
    if r is None:
        print 'Symantec call failed!'
        return
    match = r.groups()[0]
    if match == "bad":
        status = (':reputation:' + red('Bad') + ':Link:'
        'http://investigate.brightmail.com/lookup/?currentIP=' + IP)
    elif match == 'neutral':
        status = ':reputation:' + green('Neutral')

    print 'IP:' + IP + ':RBL:Symantec' + status

def att():
    import telnetlib

    host = 'ff-ip4-mx-vip1.prodigy.net.'
    port = '25'

    tn = telnetlib.Telnet(host, port)
    tn.read_until('220', 3)
    tn.write('helo telnettest\n')
    tn.read_until('250', 3)
    tn.write('mail from:<>\n')
    result = tn.expect(['Sender ok', 'http\:\/\/att\.net\/blocks'], 5)
    if result[0] is 1:
        status = red('LISTED')
    else:
        status = green('UNLISTED')
    print 'IP:' + getIPs()[0] + ':RBL:AT&T:status:' + status

def verizon():
    import telnetlib

    host = 'relay.verizon.net.'
    port = '25'

    tn = telnetlib.Telnet(host, port)
    result = tn.expect(['220', 'is currently blocked by Verizon Online\'s anti-spam system'], 5)
    if result[0] is 1:
        status = red('LISTED')
    else:
        status = green('UNLISTED')
    print 'IP:' + getIPs()[0] + ':RBL:Verizon:status:' + status

def proofpoint(IP):
    try:
        req = urllib2.Request('https://support.proofpoint.com/rbl-lookup.cgi?ip=' + IP)
        data = urllib2.urlopen(req).read()
    except urllib2.URLError, e:
        print "Proofpoint rejected for reason: " + str(e.code)
        return
      

    notListed = 'Your IP address is not currently being blocked'

    if notListed in data:
         print 'IP:' + IP + ':RBL:ProofPoint' + ':status:' + green('UNLISTED') 
    else:
         print 'IP:' + IP + ':RBL:ProofPoint' + ':status:' + red('LISTED')


def senderbase(IP):
    regex = re.compile("Email.Reputation.*?leftside..(\w+)..div", re.MULTILINE|re.DOTALL)
    postdata = [('tos_accepted', 'Yes, I Agree')]
    postdata = urllib.urlencode(postdata)
    
    opener = urllib2.build_opener(urllib2.HTTPHandler)
    request = urllib2.Request('http://www.senderbase.org/lookup/?search_string=' + IP, data=postdata)
    
    try:
        url = opener.open(request)
        data = url.read()
    except urllib2.URLError, e:
        print "SenderBase rejected for reason: " + str(e.code)
        return

    r = regex.search(data)
    match = None
    if r is None:
        print 'Senderbase call failed!'
        return
    match = r.groups()[0]
    if match == "Poor":
        status = ':reputation:' + red('Poor')
    elif match == 'Good':
        status = ':reputation:' + green('Good')
    elif match == 'Neutral':
        status = ':reputation:' + 'Neutral'

    print 'IP:' + IP + ':RBL:SenderBase' + status    

def trendmicro(IP):
    regex = re.compile('Reputation:..dt.*?dd.*?>(.*?)<\/dd.*?Feedback.*?href..(.*?)\"', re.MULTILINE|re.DOTALL)
    postdata = [('_method', 'POST'), ('data[Reputation][ip]', IP)]
    postdata = urllib.urlencode(postdata)

    opener = urllib2.build_opener(urllib2.HTTPHandler)
    request = urllib2.Request('https://ers.trendmicro.com/reputations', data=postdata)
    

    try:
        url = opener.open(request)
    except urllib2.URLError, e:
        print "TrendMicro rejected for reason: " + str(e.code)
        return
    data = url.read()

    r = regex.search(data)
    match = r.groups()[0]
    feedback = r.groups()[1]
    if match == 'Bad':
        status = red('LISTED') + ':reason:https://ers.trendmicro.com' + feedback
        
    elif match == 'Unlisted in the spam sender list':
        status = green('UNLISTED')

    print 'IP:' + IP + ':RBL:TrendMicro' + ':status:' + status

def senderscore(ip):
    rev_ip = reverseIP(ip)
    query = rev_ip + '.score.senderscore.com'
    try:
        result = socket.gethostbyname(query)
    except socket.gaierror, e:
        print 'IP:' + ip + ':RBL:' + 'SenderScore-Rep' + ':status:' + green('NO-SCORE')
        return

    if result.startswith('127.0.4'):
        reputation = result.split('.')[3]
        print ('IP:' + ip + ':RBL:' + 'SenderScore-Rep' + ':status:' + reputation + ':Link:' + 
        'https://www.senderscore.org/lookup.php?lookup=' + ip)
    else:
        print 'IP:' + ip + ':RBL:' + 'SenderScore-Rep' + ':status:' + green('NO-SCORE')
        return

def microsoft(IP):
    match = False
    opener = urllib2.build_opener(urllib2.HTTPHandler)
    request = urllib2.Request('https://postmaster.live.com/snds/ipStatus.aspx?key=e585c177-4e4f-d624-588f-a8370876c183')
    try:
        url = opener.open(request)
    except urllib2.URLError, e:
        print "Microsoft rejected for reason: " + str(e)
        return
    for row in csv.reader(url.read().decode('utf-8').splitlines()):
        if(addressInRange(IP, row[0], row[1]) == True):
            match = True
            print 'IP:' + IP + ':RBL:Microsoft' + ':status:' + red('LISTED') + ':reason:' + row[3]
            break
    if match is False:
        print 'IP:' + IP + ':RBL:Microsoft' + ':status:' + green('UNLISTED')

def ip2long(ip):
    """
    Convert an IP string to long
    """
    packedIP = socket.inet_aton(ip)
    return struct.unpack("!L", packedIP)[0]

def addressInRange(myip, startip, endip):
    if ip2long(startip) <= ip2long(myip) <= ip2long(endip):
        return True
    return False


def signal_handler(signal, frame):
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def red(text):
    return '\033[31m' + text + '\033[0m'

def green(text):
    return '\033[32m' + text + '\033[0m'

def valid_IP(ip):
    try:
        socket.inet_pton(socket.AF_INET, ip)
    except socket.error:
        return False

    return True



RBLs = urllib2.urlopen("http://legal.hostdime.com/tjb_env/rbls").read().rstrip().split('\n')
RBLs = [ x.split(';') for x in RBLs]
reverseIP = lambda x: '.'.join(x.split('.')[::-1])

if opts.list_rbls:
    print 'Major DNSRBLs:'
    print '~' * 80
    for rbl in RBLs:
        print rbl[0] + ':' + rbl[1] + ':' + rbl[2]
    print '~' * 80
    sys.exit()
                

ipList = []
if len(args) > 0 and 'netaddr' in sys.modules:

    for arg in args:
        if '/' in arg:
            try:
                ips = IPNetwork(arg)
                ipList.extend(ips)
            except AddrFormatError, e:
                print e
                continue
        else:
            try:
                ip = IPAddress(arg)
                ipList.append(ip)
            except AddrFormatError, e:
                print e
                continue
else: 
    if len(args) == 0 and not opts.all_ips:
        ipList = [getIPs()[0]]
    if opts.all_ips:
        ipList = getIPs()
    if len(args) > 0:
        for arg in args:
            if valid_IP(arg):
                ipList.append(arg)
print '~' * 80
print ''
for ip in ipList:
    ip = str(ip)
    rev_ip = reverseIP(ip)
    if opts.dnsrbl:
        query = rev_ip + '.' + opts.dnsrbl
        try:
            result = socket.gethostbyname(query)
        except socket.gaierror, e:
            print 'IP:' + ip + ':RBL:' + opts.dnsrbl + ':status:' + green('UNLISTED')
            continue

        if result.startswith('127.0.0'):
                print 'IP:' + ip + ':RBL:' + opts.dnsrbl + ':status:' + red('LISTED')
                continue
        else:
            print 'IP:' + ip + ':RBL:' + opts.dnsrbl + ':status:' + green('UNLISTED')
            continue

    else:
        print '~' * 80
        for rbl in RBLs:
            query = rev_ip + '.' + rbl[1]
            try:
                result = socket.gethostbyname(query)
            except socket.gaierror, e:
                print 'IP:' + ip + ':RBL:' + rbl[0] + ':status:' + green('UNLISTED')
                continue
              
            if result.startswith('127.0.0'):
                print 'IP:' + ip + ':RBL:' + rbl[0] + ':status:' + red('LISTED') + ':Link:' + rbl[2]
            else:
                print 'IP:' + ip + ':RBL:' + rbl[0] + ':status:' + green('UNLISTED')
                continue

    if opts.check_proofpoint:
        proofpoint(ip)

    if opts.check_microsoft:
        microsoft(ip)

    if opts.check_senderbase:
        senderbase(ip)

    if opts.check_trendmicro:
        trendmicro(ip)

    if opts.check_att:
        att()

    if opts.check_verizon:
        verizon()
    
    if opts.check_symantec:
        symantec(ip)
    
    if opts.check_senderscore:
        senderscore(ip)
    
    if opts.check_all_rbls:
        proofpoint(ip)
        microsoft(ip)
        senderbase(ip)
        trendmicro(ip)
        symantec(ip)
        senderscore(ip)

    print '~' * 80
    print ''
print '~' * 80
print ''
