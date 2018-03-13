
import requests
import json

headers = {"X-SessionID": "", "Content-type": "application/json", "Accept": "application/json"} # Use in subsequent requests

# Get session ID
data = {'username': 'HansL', 'password': 'hans'}
r = requests.post('http://localhost:3003/grape/login', data=json.dumps(data), headers=headers)

print r.status_code
print r.headers
obj = r.json()

headers['X-SessionID'] = obj['session_id']

# Your requests here




# Logout
r = requests.post("http://localhost:3003/grape/logout", headers=headers);
print r.status_code
print r.headers


