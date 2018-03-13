import urllib3
import json
import getpass
import datetime
import os
import pickle

# path refers to path part of protocol://hostname:port/path
http = urllib3.PoolManager()

class APIError(Exception):
    pass

class GrapeClient(object):
    default_login_path = '/grape/login'

    def __init__(self, base_url, name, encoding='utf8', silence_warnings=True):
        self._base_url = base_url
        self.name = name
        self.encoding = encoding
        self._headers = {"X-SessionID": "", "Content-type": "application/json", "Accept": "application/json"}
        self.set_session_data()
        self.workdir = os.path.expanduser('~/.ps/{}'.format(name))
        if silence_warnings:
            self.silence_warnings()

    def save_var(self, varName, value):
        save_path = os.path.join(self.workdir, varName + '.pickle')
        if not os.path.exists(self.workdir):
            os.makedirs(self.workdir)
        pickle.dump(value, open(save_path, 'wb'))
        os.chmod(save_path, 0o600)

    def load_var(self, varName, default=None):
        save_path = os.path.join(self.workdir, varName + '.pickle')
        if not os.path.exists(save_path):
            return default
        else:
            return pickle.load(open(save_path, 'rb'))

    def silence_warnings(self):
        urllib3.disable_warnings()

    def set_session_data(
            self,
            username=None,
            user_id=None,
            user_rolese=None,
            fullnames=None,
            email=None,
            employee_guid=None,
            session_id = '',
            **kwargs):

        self._session_id = self._headers["X-SessionID"] = session_id
        self._username = username
        self._user_id = user_id
        self._user_roles = user_rolese
        self._fullnames = fullnames
        self._email = email
        self._employee_guid = employee_guid
        self._session_timestamp = datetime.datetime.now()

        self._session_data = {
                'username': self._username,
                'user_id': self._user_id,
                'user_rolese': self._user_roles,
                'fullnames': self._fullnames,
                'email': self._email,
                'employee_guid': self._employee_guid,
                'session_id': self._session_id,
                'session_timestamp': self._session_timestamp}


    def getJSON(self, path, params=None):
        url = self._base_url + path
        response = http.request(
                'GET',
                url,
                fields = params,
                headers=self._headers
                )
        try:
            data = json.loads(response.data.decode(self.encoding))
        except json.JSONDecodeError as e:
            print(response.data.decode(self.encoding))
            raise e
        if data.get('status', 'OK').lower() == 'error':
            raise APIError(data['message'])
        return data
        

    def postJSON(self, path, params=None):
        url = self._base_url + path
        response = http.request(
                'POST',
                url,
                body = json.dumps(params).encode(self.encoding),
                headers=self._headers
                )
        try:
            data = json.loads(response.data.decode(self.encoding))
        except json.JSONDecodeError as e:
            print(response.data.decode(self.encoding))
            raise e
        if data.get('status', 'OK').lower() == 'error':
            raise APIError(data['message'])
        return data

    def login(self, username=None, password=None, path=default_login_path):
        if username is None:
            username = input('Username:')
        if password is None:
            password = getpass.getpass('Password:')
        response = self.postJSON(path, params={'username': username, 'password': password})
        self.set_session_data(**response)
        self.save_var('session_id', self._session_id)
        return response

    def load_last_session(self):
        session_id = self.load_var('session_id')
        if session_id is None or session_id == '':
            return ''
        else:
            self.session_ping(session_id)
            return session_id

    def session_ping(self, session_id = None):
        session_id = self._session_id if session_id is None else session_id
        response = self.getJSON('/grape/session_ping', params={'session_id': session_id})
        if response['status'] == 'ERROR':
            raise APIError(response['message'])
        self.set_session_data(**response)
        return self._session_id

    def connect(self):
        if self._session_id == '':
            try:
                self.load_last_session()
            except APIError as e:
                print(str(e))
                self._session_id = ''

        if self._session_id != '':
            print('Logged in as ', self._username)
        else:
            print('No current session active, please login.')
            self.login()
        
        if self._session_id == '':
            print('Failed to connect')
        return self._session_id

        
