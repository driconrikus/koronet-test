import unittest
import json
from unittest.mock import patch, MagicMock
from app import app # Assuming your Flask app is named 'app' in app.py

class FlaskAppTests(unittest.TestCase):

    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    @patch('app.psycopg2.connect')
    @patch('app.redis.Redis')
    def test_hello_koronet_db_and_redis_connected(self, mock_redis, mock_psycopg2_connect):
        # Configure mock PostgreSQL connection
        mock_conn = MagicMock()
        mock_psycopg2_connect.return_value = mock_conn
        mock_cursor = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        # Configure mock Redis connection
        mock_redis_instance = MagicMock()
        mock_redis.return_value = mock_redis_instance
        mock_redis_instance.ping.return_value = True

        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"DB Status: Connected", response.data)
        self.assertIn(b"Redis Status: Connected", response.data)
        
        mock_psycopg2_connect.assert_called_once() # Ensure connect was called
        mock_redis.assert_called_once() # Ensure Redis was called

    @patch('app.psycopg2.connect', side_effect=Exception("Mock DB Error"))
    @patch('app.redis.Redis')
    def test_hello_koronet_db_error(self, mock_redis, mock_psycopg2_connect):
        # Configure mock Redis connection (successful to isolate DB error)
        mock_redis_instance = MagicMock()
        mock_redis.return_value = mock_redis_instance
        mock_redis_instance.ping.return_value = True

        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"DB Status: Error: Mock DB Error", response.data)
        self.assertIn(b"Redis Status: Connected", response.data)
        mock_psycopg2_connect.assert_called_once()

    @patch('app.psycopg2.connect')
    @patch('app.redis.Redis', side_effect=Exception("Mock Redis Error"))
    def test_hello_koronet_redis_error(self, mock_redis, mock_psycopg2_connect):
        # Configure mock PostgreSQL connection (successful to isolate Redis error)
        mock_conn = MagicMock()
        mock_psycopg2_connect.return_value = mock_conn
        mock_cursor = MagicMock()
        mock_conn.cursor.return_value = mock_cursor

        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"DB Status: Connected", response.data)
        self.assertIn(b"Redis Status: Error: Mock Redis Error", response.data)
        mock_redis.assert_called_once()

if __name__ == '__main__':
    unittest.main()
