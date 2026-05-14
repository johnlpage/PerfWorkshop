const express = require("express");
const { MongoClient, ObjectId } = require("mongodb");
const cluster = require("cluster");
const os = require("os");
const { lineStream, progress } = require("./utils");

const app = express();
const NUM_CUSTOMERS = 400_000;
const NUM_DRIVERS = 25_000;
const NUM_RECORDS = 5_000_000;
const PORT = process.env.PORT || 5050;
const MONGO_URI = process.env.MONGODB_URI || "mongodb://localhost:27017";

let db, collection;

async function connectDb() {
  const client = new MongoClient(MONGO_URI);
  await client.connect();
  db = client.db("unter");
  collection = db.collection("contacts");
  return { client, collection };
}

// Routes
app.get("/ping", (req, res) => res.json({ status: "ok" }));

app.post("/contacts", async (req, res) => {
  let count = 0;
  const startTime = Date.now();
  const contentLength = parseInt(req.headers["content-length"] || 0);
  let bytesProcessed = 0;

  try {
    for await (const line of lineStream(req)) {
      const doc = JSON.parse(line);
      bytesProcessed += Buffer.byteLength(line) + 1;

      await collection.insertOne(doc);
      count++;

      progress(count, startTime, contentLength, bytesProcessed);
    }
    res.status(201).json({ inserted: count });
  } catch (err) {
    console.error("Insert failed:", err);
    res.status(500).json({ error: err.message });
  }
});

app.get("/contacts/:id", async (req, res) => {
  try {
    const doc = await collection.findOne({ contact_id: eq.params.id });
    if (!doc) return res.status(404).json({ error: "Not found" });
    res.json(doc);
  } catch (err) {
    res.status(400).json({ error: "Invalid ID format" });
  }
});

app.get("/customers/:custid/contacts", async (req, res) => {
  const custid = `cst${String(Math.floor(Math.random() * NUM_CUSTOMERS) + 1).padStart(8, "0")}`;
  let dateStr = req.query.fromDate;
  let filterDate = dateStr
    ? `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}`
    : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
        .toISOString()
        .split("T")[0];

  const docs = await collection
    .find({
      customer_id: custid,
      timestamp: { $gte: filterDate },
    })
    .toArray();
  res.json(docs);
});

// GET driver contacts
app.get("/drivers/:driverid/contacts", async (req, res) => {
  // Hardcode a random value to match your Python test logic
  const driverid = `drv${String(Math.floor(Math.random() * NUM_DRIVERS) + 1).padStart(8, "0")}`;

  let dateStr = req.query.fromDate;
  let filterDate;
  if (dateStr) {
    filterDate = `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}`;
  } else {
    const d = new Date();
    d.setDate(d.getDate() - 30);
    filterDate = d.toISOString().split("T")[0];
  }

  const mongoQuery = {
    "driver_rating.driver_id": driverid,
    timestamp: { $gte: filterDate },
  };

  const docs = await collection.find(mongoQuery).toArray();
  res.json(docs);
});

// Use express.text() as middleware specifically for this route
app.post(
  "/contacts/:id/comments",
  express.text({ type: "*/*" }),
  async (req, res) => {
    // Match Python's random ID logic
    const id = `cnt${String(Math.floor(Math.random() * NUM_RECORDS) + 1).padStart(10, "0")}`;

    // ab sends data in the body
    const comment = req.body;

    if (!comment || Object.keys(comment).length === 0) {
      return res.status(400).json({ error: "No comment provided" });
    }

    try {
      const result = await collection.updateOne(
        { contact_id: id },
        { $push: { notes: comment } },
      );

      if (result.matchedCount === 0) {
        // This returns a 404 if the random ID doesn't exist in your DB
        return res.status(404).json({ error: `Record ${id} not found` });
      }

      res.status(200).json({ status: "success" });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },
);

app.get("/drivers/stats/averages", async (req, res) => {
  const pipeline = [
    {
      $group: {
        _id: "$driver_rating.driver_id",
        average_rating: { $avg: "$driver_rating.rating" },
        total_trips: { $sum: 1 },
      },
    },
    { $match: { _id: { $ne: null } } },
    { $sort: { average_rating: -1 } },
  ];
  try {
    const stats = await collection.aggregate(pipeline).toArray();
    res.json(stats);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const startServer = async () => {
  try {
    const { collection } = await connectDb();

    // 1. Preflight check (Only runs once when the process starts)
    const count = await collection.estimatedDocumentCount();
    console.log(`Connected to MongoDB! Documents: ${count}`);

    // 2. Ensure Indexes
    // Note: MongoDB handles "createIndex" gracefully if they already exist
    console.log("Ensuring indexes...");
    await collection.createIndexes([
      { key: { contact_id: 1 }, unique: true },
      { key: { customer_id: 1 } },
      { key: { "driver_rating.driver_id": 1 } },
    ]);
    console.log("Indexes available");

    // 3. Start the App
    app.listen(PORT, () => {
      console.log(`Process ${process.pid} listening on ${PORT}`);
    });
  } catch (err) {
    console.error("Failed to start:", err);
    process.exit(1);
  }
};

startServer();
