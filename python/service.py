import json
import os
import random
import time
import logging
from flask import Flask, request, jsonify
from pymongo import MongoClient
from bson import ObjectId
from utils import line_stream, progress, GunicornApp
from datetime import UTC, datetime, timedelta

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
NUM_RECORDS = 5_000_000  # Adjust as needed
NUM_CUSTOMERS = 400_000
NUM_VEHICLES = 20_000
NUM_DRIVERS = 25_000
NUM_LOCATIONS = 10_000

client = None
collection = None

def pre_flight():
    global client, collection
    client = MongoClient(
        os.environ.get("MONGODB_URI", "mongodb://localhost:27017")
    )
    collection = client["unter"]["contacts"]
    client.admin.command("ping")
    count = collection.estimated_document_count()
    print(f"Preflight check: Connected to MongoDB! Document count: {count}")
    print("Ensuring required indexes...")
    collection.create_index("contact_id", unique=True)
    collection.create_index("customer_id")
    collection.create_index("driver_rating.driver_id")

# Called after fork() of new process for safety so each has own driver
def init_db(server, worker):
    global client, collection
    client = MongoClient(
        os.environ.get("MONGODB_URI", "mongodb://localhost:27017")
    )
    collection = client["unter"]["contacts"]



@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"})


@app.route("/contacts", methods=["POST"])
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


@app.route("/contacts/<id>", methods=["GET"])
def get_thing(id):
    doc = collection.find_one({"_id": ObjectId(id)})
    if not doc:
        return jsonify({"error": "Not found"}), 404
    doc["_id"] = str(doc["_id"])
    return jsonify(doc),200


@app.route("/customers/<custid>/contacts", methods=["GET"])
def get_customer_contacts(custid):

    # hard code a random value to make tests easier
    custid = f"cst{random.randint(1, NUM_CUSTOMERS):08d}"
    datestring = request.args.get("fromDate")
    if datestring:
        formatted_date = datetime.strptime(datestring, "%Y%m%d").strftime("%Y-%m-%d")
    else:
        formatted_date = (datetime.now(UTC) - timedelta(days=30)).strftime("%Y-%m-%d")

    mongo_query = {"customer_id": custid, "timestamp": {"$gte": formatted_date}}
    docs = list(collection.find(mongo_query))
    for doc in docs:
        doc["_id"] = str(doc["_id"])
    return jsonify(docs),200


@app.route("/drivers/<driverid>/contacts", methods=["GET"])
def get_driver_contacts(driverid):

    # hard code a random value to make tests easier
    driverid = f"drv{random.randint(1, NUM_DRIVERS):08d}"
    datestring = request.args.get("fromDate")
    if datestring:
        formatted_date = datetime.strptime(datestring, "%Y%m%d").strftime("%Y-%m-%d")
    else:
        formatted_date = (datetime.now(UTC) - timedelta(days=30)).strftime("%Y-%m-%d")

    mongo_query = {
        "driver_rating.driver_id": driverid,
        "timestamp": {"$gte": formatted_date},
    }
    docs = list(collection.find(mongo_query))
    for doc in docs:
        doc["_id"] = str(doc["_id"])

    return jsonify(docs),200

app.route("/contacts/<id>/comments", methods=["POST"])
def add_comment(id):

    id = f"cnt{random.randint(1, NUM_RECORDS):010d}"
    # Extract the comment string from the POST body
    # Using request.get_data(as_text=True) to get the raw string
    comment = request.get_data(as_text=True)
    
    if not comment:
        return jsonify({"error": "No comment provided"}), 400

    # Update the document by pushing the string into the 'notes' array
    result = collection.update_one(
        {"contact_id": id}, 
        {"$push": {"notes": comment}}
    )

    if result.matched_count == 0:
        return jsonify({"error": f"Record {id} not found"}), 404

    return jsonify({
        "status": "success", 
        "updated_record_id": id, 
        "comment_added": comment
    }), 200

@app.route("/drivers/stats/averages", methods=["GET"])
def get_driver_averages():
    pipeline = [
        # 1. Group by the driver_id inside the driver_rating object
        {
            "$group": {
                "_id": "$driver_rating.driver_id",
                "average_rating": {"$avg": "$driver_rating.rating"},
                "total_trips": {"$sum": 1}
            }
        },
        # 2. Optional: Only show drivers with actual IDs (filters out nulls)
        {"$match": {"_id": {"$ne": None}}},
        # 3. Sort by highest rated first
        {"$sort": {"average_rating": -1}}
    ]

    try:
        # Use allowDiskUse=True since you have 5M records; 
        # this prevents the 100MB RAM limit error in MongoDB aggregations
        stats = list(collection.aggregate(pipeline, allowDiskUse=True))
        return jsonify(stats), 200
    except Exception as e:
        logger.error(f"Aggregation failed: {e}")
        return jsonify({"error": str(e)}), 500
    
if __name__ == "__main__":
    pre_flight()
    options = {
        "bind": "0.0.0.0:5050",
        "workers": 4,
        "timeout": 600,
        "post_fork": init_db,
    }
    GunicornApp(app, options).run()
