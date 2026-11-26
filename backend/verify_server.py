import urllib.request

with urllib.request.urlopen('http://127.0.0.1:8000/api/health') as resp:
    print('Health:', resp.status, resp.read().decode())

with urllib.request.urlopen('http://127.0.0.1:8000/') as resp:
    body = resp.read().decode()
    print('Index loaded:', resp.status, 'len:', len(body))
    print('Get Started button present:', 'id="btnGetStarted"' in body)
    print('onclick showView present:', "onclick=\"showView('login')\"" in body)
