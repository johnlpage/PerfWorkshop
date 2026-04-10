import json
import os
import logging
from flask import Flask, request, jsonify
from pymongo import MongoClient
from bson import ObjectId
from gunicorn.app.base import BaseApplication

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)


def line_stream(chunk_size=64 * 1024):
    """Read the request stream in chunks and yield complete lines."""
    buffer = ""
    while True:
        chunk = request.stream.read(chunk_size)
        if not chunk:
            break
        buffer += chunk.decode("utf-8")
        while "\n" in buffer:
            line, buffer = buffer.split("\n", 1)
            line = line.strip()
            if line:
                yield line
    # Don't forget the last line if no trailing newline
    buffer = buffer.strip()
    if buffer:
        yield buffer


client = MongoClient(os.environ.get("MONGODB_URI", "mongodb://localhost:27017"))
collection = client["unter"]["events"]
try:
    client.admin.command('ping')
    count = collection.estimated_document_count();
    logger.info(f"Successfully connected to MongoDB! Current document count: {count}")
except Exception as e:
    logger.cinfo(f"Failed to connect to MongoDB: {e}")



@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"})


@app.route("/events", methods=["POST"])  
def insert():  
    count = 0  
    batch = []  
  
    for line in line_stream():  # <-- use line_stream(), not request.stream  
        try:  
            doc = json.loads(line)  
        except json.JSONDecodeError:  
            logger.error(f"Failed to parse line: {line[:100]}")  
            continue  
  
        collection.insert_one(doc)  
        count = count + 1
  
  
    return jsonify({"inserted": count}), 201  





# GET /events/<id> - Fetch a thing by ID
@app.route("/events/<id>", methods=["GET"])
def get_thing(id):
    doc = collection.find_one({"_id": ObjectId(id)})
    if not doc:
        return jsonify({"error": "Not found"}), 404
    doc["_id"] = str(doc["_id"])
    return jsonify(doc)


# GET /customers/<custid>/events - Fetch events for a specific customer
@app.route("/customers/<custid>/events", methods=["GET"])
def get_customer_events(custid):
    limit = request.args.get("limit", 10, type=int)
    docs = list(collection.find({"custid": custid}).limit(limit))
    for doc in docs:
        doc["_id"] = str(doc["_id"])
    return jsonify(docs)


# Gunicorn fund flask multiprocess for production use, but we can also run it directly for testing
# It means we don't hit the GIL using python and pymongo


class GunicornApp(BaseApplication):  
    def __init__(self, app, options=None):  
        self.application = app  
        self.options = options or {}  
        super().__init__()  
  
    def load_config(self):  
        for key, value in self.options.items():  
            self.cfg.set(key, value)  
  
    def load(self):  
        return self.application 

if __name__ == "__main__":
    options = {
        "bind": "0.0.0.0:5050",
        "workers": 4,
        "timeout": 600,
    }
    GunicornApp(app, options).run()
