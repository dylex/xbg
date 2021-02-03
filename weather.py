#!/usr/bin/python3

import os
import sys
import getopt
import requests
import json
import time
import datetime
import isodate

HEADERS = {'user-agent': 'https://github.com/dylex/xbg weather'}
CACHE_PFX = os.path.expanduser("~/.cache/xbg/weather.")
OPTS = ''

def readGeopos(path):
    with open(path) as f:
        l = next(f)
    return map(float, l.strip().split(' '))

def cacheFile(name):
    return os.path.join(CACHE_DIR, name)

def getCache(path, url, expire):
    if 'f' in OPTS:
        return
    try:
        with open(path+'.url', 'r') as k:
            if next(k) != url:
                return
        with open(path, 'r') as c:
            if 'n' not in OPTS:
                stat = os.fstat(c.fileno())
                if time.time() - stat.st_mtime > expire:
                    return
            return json.load(c)
    except IOError as e:
        if 'n' in OPTS:
            raise e

def loadURL(url, cache, expire):
    path = CACHE_PFX + cache
    cache = getCache(path, url, expire)
    if cache:
        return cache
    if 'v' in OPTS:
        print(url)
    res = requests.get(url, headers=HEADERS)
    j = res.json()
    if 'status' in j and j['status'] >= 300:
        raise ValueError(j)
    with open(path, 'wb') as c:
        c.write(res.content)
    with open(path+'.url', 'w') as k:
        k.write(url)
    return res.json()

UOMs = {
    'degC': lambda c: 1.8*c + 32,
    'percent': lambda p: p,
    'degree_(angle)': lambda d: d,
    'km_h-1': lambda k: 0.62137119*k
}

def stripprefix(p, s):
    if s.startswith(p):
        return s[len(p):]
    return s

def parseISO(x):
    (s,d) = x.split('/')
    s = isodate.parse_datetime(s)
    e = s + isodate.parse_duration(d)
    return (s, e)

def parseValue(v):
    if not v or v['value'] is None: return
    return UOMs[stripprefix('unit:',v['unitCode'])](v['value'])

def parseValues(v):
    c = UOMs[stripprefix('wmoUnit:', v['uom'])]
    return ((parseISO(x['validTime']), c(x['value'])) for x in v['values'])

def fmt(x):
    return '%.f'%(x) if x is not None else ''

def printSamples(init, start, l, interval=datetime.timedelta(hours=1)):
    s = fmt(init)
    t = start
    for x in l:
        while t < x[0][1]:
            s += ' ' + fmt(x[1] if t >= x[0][0] else None)
            t = t + interval
    print(s)

if __name__ == '__main__':
    (opts, _) = getopt.getopt(sys.argv[1:], 'nfv')
    OPTS = ''.join(o.lstrip('-') for (o,_) in opts)
    os.makedirs(os.path.dirname(CACHE_PFX), exist_ok=True)

    try:
        g = readGeopos(os.path.expanduser('~/.geopos'))
    except IOError:
        g = readGeopos('/etc/geopos')
    urls = loadURL('https://api.weather.gov/points/%f,%f'%tuple(g), 'points', 7654321)['properties']

    station = loadURL(urls['observationStations'], 'stations', 654321)['observationStations'][0]
    obs = loadURL(station+'/observations/latest', 'observation', 321)['properties']

    forecast = loadURL(urls['forecastGridData'], 'forecast', 4321)['properties']
    now = datetime.datetime.now(tz=datetime.timezone.utc)

    print((obs['icon'] or '').split('/').pop().split('?').pop(0))

    ext = list(parseValues(forecast['maxTemperature']))
    ext.extend(parseValues(forecast['minTemperature']))
    ext.sort(key=lambda x: x[0][0])
    printSamples(parseValue(obs['temperature']), now, ext)
    for t in ['temperature', 'dewpoint', 'skyCover', 'probabilityOfPrecipitation', 'windSpeed', 'windDirection']:
        printSamples(parseValue(obs.get(t)), now, parseValues(forecast[t]))
