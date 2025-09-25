import unittest
import json
from app import app # Assuming your Flask app is named 'app' in app.py

class FlaskAppTests(unittest.TestCase):

    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_hello_koronet_status_code(self):
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)

    def test_hello_koronet_content(self):
        response = self.app.get('/')
        self.assertIn(b"Hi Koronet Team.", response.data)

    def test_hello_koronet_db_status_connected(self):
        # This test assumes successful DB connection, which might not be true in a CI environment without a running DB
        # For a more robust test, you'd mock the DB connection.
        response = self.app.get('/')
        self.assertIn(b"DB Status: Connected", response.data) # Or check for Error if DB is not mocked

    def test_hello_koronet_redis_status_connected(self):
        # This test assumes successful Redis connection, which might not be true in a CI environment without a running Redis
        # For a more robust test, you'd mock the Redis connection.
        response = self.app.get('/')
        self.assertIn(b"Redis Status: Connected", response.data) # Or check for Error if Redis is not mocked

if __name__ == '__main__':
    unittest.main()
