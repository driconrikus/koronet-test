
from flask import Flask
import os

app = Flask(__name__)

# Database configuration
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "koronet_db")
DB_USER = os.environ.get("DB_USER", "koronet_user")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "koronet_password")

# Redis configuration
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))

@app.route('/')
def hello_koronet():
    db_status = "Disconnected"
    redis_status = "Disconnected"

    # PostgreSQL connection attempt
    try:
        import psycopg2
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD)
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        db_status = "Connected"
    except Exception as e:
        db_status = f"Error: {e}"

    # Redis connection attempt
    try:
        import redis
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
        r.ping()
        redis_status = "Connected"
    except Exception as e:
        redis_status = f"Error: {e}"

    return f"Hi Koronet Team. DB Status: {db_status}. Redis Status: {redis_status}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
