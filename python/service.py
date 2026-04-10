import json  
import os 
import logging  
from flask import Flask, request, jsonify  
from pymongo import MongoClient  
from bson import ObjectId  
  
logging.basicConfig(level=logging.INFO)  
logger = logging.getLogger(__name__)  
  
app = Flask(__name__)  
client = MongoClient(os.environ.get("MONGODB_URI", "mongodb://localhost:27017"))  
collection = client["streamdb"]["documents"]  
  
  
@app.route("/ping", methods=["GET"])  
def ping():  
    return jsonify({"status": "ok"})  
  
  
@app.route("/things", methods=["POST"])  
def insert():  
    count = 0  
    for line in request.stream:  
        text = line.decode().strip()  
        if not text:  
            continue  
        try:  
            doc = json.loads(text)  
        except json.JSONDecodeError:  
            logger.error(f"Failed to parse line: {text}")  
            continue  
        collection.insert_one(doc)  
        count += 1  
    return jsonify({"inserted": count},201)  
  

@app.route("/things", methods=["PUT"])  
def replace():  
    count = 0  
    for line in request.stream:  
        text = line.decode().strip()  
        if not text:  
            continue  
        try:  
            doc = json.loads(text)  
        except json.JSONDecodeError:  
            logger.error(f"Failed to parse line: {text}")  
            continue  
        collection.replace_one({"_id": doc.get("_id")}, doc, upsert=True)  
        count += 1  
    return jsonify({"inserted": count},201)  
  


@app.route("/things", methods=["PATCH"])  
def update():  
    count = 0  
    for line in request.stream:  
        text = line.decode().strip()  
        if not text:  
            continue  
        try:  
            doc = json.loads(text)  
        except json.JSONDecodeError:  
            logger.error(f"Failed to parse line: {text}")  
            continue
        if "_id" not in doc:
            logger.error(f"Document missing _id: {text}")  
            continue
        collection.update_one({"_id": doc.get("_id")}, {"$set": doc}, upsert=True)  
        count += 1  
    return jsonify({"inserted": count},201) 

  

  
  
# GET /things/<id> - Fetch a thing by ID  
@app.route("/things/<id>", methods=["GET"])  
def get_thing(id):  
    doc = collection.find_one({"_id": ObjectId(id)})  
    if not doc:  
        return jsonify({"error": "Not found"}), 404  
    doc["_id"] = str(doc["_id"])  
    return jsonify(doc)  
  
  
# GET /customers/<custid>/things - Fetch things for a specific customer  
@app.route("/customers/<custid>/things", methods=["GET"])  
def get_customer_things(custid):  
    limit = request.args.get("limit", 10, type=int)  
    docs = list(collection.find({"custid": custid}).limit(limit))  
    for doc in docs:  
        doc["_id"] = str(doc["_id"])  
    return jsonify(docs)  
  
  
if __name__ == "__main__":  
    app.run(port=5050, processes=16, debug=False)  
