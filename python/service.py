import json  
import logging  
from flask import Flask, request, jsonify  
from pymongo import MongoClient  
  
logging.basicConfig(level=logging.INFO)  
logger = logging.getLogger(__name__)  
  
app = Flask(__name__)  
client = MongoClient("mongodb://localhost:27017")  
collection = client["streamdb"]["documents"]  
  
  
@app.route("/ingest", methods=["POST"])  
def ingest():  
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
    return jsonify({"inserted": count})  

@app.route("/ping", methods=["GET"])  
def ping():  
    return true;
  
if __name__ == "__main__":  
    app.run(port=5050)  
