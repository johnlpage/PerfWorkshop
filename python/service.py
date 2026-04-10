import json  
import os  
import time  
import logging  
from flask import Flask, request, jsonify  
from pymongo import MongoClient  
from bson import ObjectId  
from utils import line_stream, progress, GunicornApp  
  
logging.basicConfig(level=logging.INFO)  
logger = logging.getLogger(__name__)  
  
app = Flask(__name__)  
  
client = None  
collection = None  

#Called after fork() of new process for safety
def init_db(server, worker):  
    global client, collection  
    client = MongoClient(os.environ.get("MONGODB_URI", "mongodb://localhost:27017"))  
    collection = client["unter"]["events"]  
    client.admin.command('ping')  
    count = collection.estimated_document_count()  
    logger.info(f"Worker {worker.pid} connected to MongoDB! Document count: {count}")  
  
  
@app.route("/ping", methods=["GET"])  
def ping():  
    return jsonify({"status": "ok"})  
  
  
@app.route("/events", methods=["POST"])  
def insert():  
    count = 0  
    batch = []  
    start_time = time.time()  
    content_length = request.content_length  
    bytes_read = [0]  
  
    for line in line_stream():  
        try:  
            doc = json.loads(line)  
        except json.JSONDecodeError:  
            logger.error(f"Failed to parse line: {line[:100]}")  
            continue  
  
        bytes_read[0] += len(line) + 1  
        collection.insert_one(doc)  
        count = count + 1  
        progress(count, start_time, content_length, bytes_read[0], logger)  
  
  
    return jsonify({"inserted": count}), 201  
  
  
@app.route("/events/<id>", methods=["GET"])  
def get_thing(id):  
    doc = collection.find_one({"_id": ObjectId(id)})  
    if not doc:  
        return jsonify({"error": "Not found"}), 404  
    doc["_id"] = str(doc["_id"])  
    return jsonify(doc)  
  
  
@app.route("/customers/<custid>/events", methods=["GET"])  
def get_customer_events(custid):  
    limit = request.args.get("limit", 10, type=int)  
    docs = list(collection.find({"custid": custid}).limit(limit))  
    for doc in docs:  
        doc["_id"] = str(doc["_id"])  
    return jsonify(docs)  
  
  
if __name__ == "__main__":  
    options = {  
        "bind": "0.0.0.0:5050",  
        "workers": 4,  
        "timeout": 600,  
        "post_fork": init_db,  
    }  
    GunicornApp(app, options).run()  
