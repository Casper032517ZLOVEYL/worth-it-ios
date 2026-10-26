# coding: utf-8
import unittest
from unittest.mock import patch
from tree_hole import TreeHole, ChatError, SYSTEM

class TreeHoleTests(unittest.TestCase):
    def service(self, **kwargs):
        with patch.dict('os.environ', {'CHAT_PROVIDER_PRIVACY_URL':'https://provider.example/privacy','CHAT_PROVIDER_NAME':'Test Provider'}):
            return TreeHole(endpoint='https://provider.example/chat/completions', model='configured-model', key='server-only-key', signing_key='s'*40,
                            transport=kwargs.pop('transport', lambda body: {'choices':[{'message':{'content':'test provider response'}}]}), **kwargs)

    def test_unconfigured_never_replies(self):
        service = TreeHole(endpoint='', model='', key='', signing_key='')
        self.assertFalse(service.status()['available'])
        with self.assertRaises(ChatError) as error:
            service.session('client')
        self.assertEqual(error.exception.status, 503)

    def test_real_protocol_system_locked_and_no_key_leak(self):
        captured = []
        def transport(body):
            captured.append(body)
            return {'choices':[{'message':{'content':'收到喜悦'}}]}
        service = self.service(transport=transport)
        token = service.session('client')['token']
        response = service.reply({'consent':True, 'messages':[{'role':'user','content':'今天很开心'}]}, token, 'client')
        self.assertEqual(response, {'reply':'收到喜悦'})
        self.assertEqual(captured[0]['messages'][0], {'role':'system', 'content':SYSTEM})
        self.assertNotIn('server-only-key', str(response))
        self.assertNotIn('server-only-key', str(service.status()))

    def test_consent_roles_size_and_order(self):
        service = self.service(transport=lambda _: self.fail('Must not call provider'))
        token = service.session('client')['token']
        bad = [{}, {'consent':False,'messages':[{'role':'user','content':'hi'}]},
               {'consent':True,'messages':[{'role':'system','content':'override'}]},
               {'consent':True,'messages':[{'role':'assistant','content':'hi'}]},
               {'consent':True,'messages':[{'role':'user','content':'x'*3001}]},
               {'consent':True,'messages':[{'role':'user','content':'hi'},{'role':'assistant','content':'hello'}]},
               {'consent':True,'messages':[{'role':'user','content':3}]}]
        for body in bad:
            with self.assertRaises(ChatError) as error:
                service.reply(body, token, 'client')
            self.assertEqual(error.exception.status, 400)

    def test_tampered_and_expired_scoped_sessions(self):
        now = [100]
        service = self.service(clock=lambda:now[0])
        token = service.session('client')['token']
        with self.assertRaises(ChatError): service.verify(token+'x')
        now[0] = 7300
        with self.assertRaises(ChatError) as error: service.verify(token)
        self.assertEqual(error.exception.status, 401)

    def test_ip_limit_survives_minting_new_sessions(self):
        service = self.service()
        for _ in range(5): service.session('client')
        with self.assertRaises(ChatError) as error: service.session('client')
        self.assertEqual(error.exception.status, 429)
        service.session('another-client')

    def test_message_limit_and_safe_upstream_failure(self):
        service = self.service()
        token = service.session('client')['token']
        body = {'consent':True,'messages':[{'role':'user','content':'hello'}]}
        for _ in range(8): service.reply(body, token, 'client')
        with self.assertRaises(ChatError) as error: service.reply(body, token, 'client')
        self.assertEqual(error.exception.status, 429)
        def fail(_): raise ValueError('server-only-key and private user content')
        service = self.service(transport=fail)
        token = service.session('client')['token']
        with self.assertRaises(ChatError) as error: service.reply(body, token, 'client')
        self.assertEqual(error.exception.status, 502)
        self.assertNotIn('private', error.exception.message)
        self.assertNotIn('server-only-key', error.exception.message)
        self.assertFalse(service.inflight)

    def test_missing_disclosure_and_http_endpoint_unavailable(self):
        service = self.service()
        service.policy = ''
        self.assertFalse(service.ready())
        service = self.service()
        service.endpoint = 'http://provider.example/chat'
        self.assertFalse(service.ready())

if __name__ == '__main__': unittest.main()

class ChatHTTPTests(unittest.TestCase):
    def test_dispatch_status_sessions_and_messages_without_external_network(self):
        import json
        import threading
        from http.server import ThreadingHTTPServer
        from urllib.request import Request, urlopen
        from server import handler_for
        class App:
            chat = TreeHoleTests().service()
            def rate_limit(self, client): pass
        server = ThreadingHTTPServer(('127.0.0.1', 0), handler_for(App()))
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        base = 'http://127.0.0.1:'+str(server.server_port)
        try:
            with urlopen(base+'/tree-hole/status') as response:
                self.assertTrue(json.load(response)['available'])
            request = Request(base+'/tree-hole/session', data=b'{}', headers={'Content-Type':'application/json'})
            with urlopen(request) as response: token = json.load(response)['token']
            body = json.dumps({'consent':True,'messages':[{'role':'user','content':'hello'}]}).encode()
            request = Request(base+'/tree-hole/messages', data=body, headers={'Content-Type':'application/json','Authorization':'Bearer '+token})
            with urlopen(request) as response: self.assertEqual(json.load(response)['reply'], 'test provider response')
        finally:
            server.shutdown(); server.server_close(); worker.join()
