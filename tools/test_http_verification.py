"""Transport retries cannot turn HTTP errors or exhausted failures into a pass."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'deploy'))
from verify_portal import perform_request

class Connection:
    def __init__(self, outcome):self.outcome=outcome;self.closed=False
    def request(self,*args,**kwargs):pass
    def getresponse(self):return self
    @property
    def status(self):return self.outcome if isinstance(self.outcome,int) else 200
    def getheaders(self):return [('Content-Type','text/html')]
    def read(self):
        if isinstance(self.outcome,Exception):raise self.outcome
        return b'known response'
    def close(self):self.closed=True

class RetryTests(unittest.TestCase):
    @patch('verify_portal.time.sleep')
    def test_partial_read_closes_before_bounded_retry(self,sleep):
        first,second=Connection(TimeoutError()),Connection(200);pool=iter([first,second]);events=[]
        status,headers,body=perform_request(lambda:next(pool),'/index.html','GET',{},events)
        self.assertEqual((status,body),(200,b'known response'))
        self.assertTrue(first.closed and second.closed);self.assertEqual(len(events),1)

    @patch('verify_portal.time.sleep')
    def test_three_failures_still_fail(self,sleep):
        connections=[]
        def create():c=Connection(TimeoutError());connections.append(c);return c
        with self.assertRaisesRegex(RuntimeError,'GET /broken failed after 3'):perform_request(create,'/broken','GET',{},[])
        self.assertEqual(len(connections),3);self.assertTrue(all(c.closed for c in connections))

    def test_http_error_is_not_retried_and_post_is_not_replayed(self):
        c=Connection(403);events=[]
        self.assertEqual(perform_request(lambda:c,'/index.html','GET',{},events)[0],403);self.assertEqual(events,[])
        c=Connection(TimeoutError())
        with self.assertRaisesRegex(RuntimeError,'after 1'):perform_request(lambda:c,'/index.html','POST',{},events)
        self.assertTrue(c.closed);self.assertEqual(events,[])

if __name__=='__main__':unittest.main()
