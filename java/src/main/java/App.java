
import static spark.Spark.*;

import com.mongodb.client.*;
import com.mongodb.client.model.*;
import com.mongodb.client.result.UpdateResult;
import org.bson.Document;
import org.bson.conversions.Bson;
import org.bson.types.ObjectId;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

public class App {

    private static final int NUM_CUSTOMERS = 400_000;
    private static final int NUM_DRIVERS = 25_000;
    private static final int NUM_RECORDS = 5_000_000;

    public static void main(String[] args) {
        String portEnv = System.getenv("PORT");
        int port = portEnv != null ? Integer.parseInt(portEnv) : 5050;

        String mongoUri = System.getenv("MONGODB_URI");
        if (mongoUri == null)
            mongoUri = "mongodb://localhost:27017";

        // Connect to MongoDB
        MongoClient mongoClient = MongoClients.create(mongoUri);
        MongoDatabase db = mongoClient.getDatabase("unter");
        MongoCollection<Document> collection = db.getCollection("contacts");

        // 1. Preflight check
        try {
            db.runCommand(new Document("ping", 1));
        } catch (Exception e) {
            System.err.println("Failed to connect to MongoDB: " + e.getMessage());
            System.exit(1);
        }
        long docCount = collection.estimatedDocumentCount();
        System.out.println("Connected to MongoDB! Documents: " + docCount);

        // 2. Ensure Indexes in a single call
        collection.createIndexes(Arrays.asList(
                new IndexModel(Indexes.ascending("contact_id"), new IndexOptions().unique(true)),
                new IndexModel(Indexes.ascending("customer_id")),
                new IndexModel(Indexes.ascending("driver_rating.driver_id"))));

        // 3. Setup Spark Server
        port(port);
        System.out.println("Process " + ProcessHandle.current().pid() + " listening on " + port);

        // Routes
        get("/ping", (req, res) -> {
            res.type("application/json");
            return "{\"status\": \"ok\"}";
        });

        post("/contacts", (req, res) -> {
            res.type("application/json");
            long startTime = System.currentTimeMillis();

            String clHeader = req.headers("content-length");
            long contentLength = clHeader != null ? Long.parseLong(clHeader) : 0;

            long bytesProcessed = 0;
            long count = 0;

            // Stream request body rather than loading it all in memory
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(req.raw().getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.trim().isEmpty())
                        continue;

                    bytesProcessed += line.getBytes(StandardCharsets.UTF_8).length + 1; // +1 for newline character

                    Document doc = Document.parse(line);
                    collection.insertOne(doc);
                    count++;

                    Utils.progress(count, startTime, contentLength, bytesProcessed, 1000);
                }
                res.status(201);
                return String.format("{\"inserted\": %d}", count);
            } catch (Exception e) {
                System.err.println("Insert failed: " + e.getMessage());
                res.status(500);
                return String.format("{\"error\": \"%s\"}", escapeJson(e.getMessage()));
            }
        });

        get("/contacts/:id", (req, res) -> {
            res.type("application/json");
            try {
                Document doc = collection.find(Filters.eq("_id", new ObjectId(req.params("id")))).first();
                if (doc == null) {
                    res.status(404);
                    return "{\"error\": \"Not found\"}";
                }
                return doc.toJson();
            } catch (IllegalArgumentException e) {
                res.status(400);
                return "{\"error\": \"Invalid ID format\"}";
            }
        });

        get("/customers/:custid/contacts", (req, res) -> {
            res.type("application/json");
            Random rand = new Random();
            String custid = String.format("cst%08d", rand.nextInt(NUM_CUSTOMERS) + 1);

            String dateStr = req.queryParams("fromDate");
            String filterDate = dateStr != null && dateStr.length() >= 8
                    ? String.format("%s-%s-%s", dateStr.substring(0, 4), dateStr.substring(4, 6),
                            dateStr.substring(6, 8))
                    : LocalDate.now().minusDays(30).toString();

            List<String> docs = collection.find(
                    Filters.and(Filters.eq("customer_id", custid), Filters.gte("timestamp", filterDate)))
                    .map(Document::toJson).into(new ArrayList<>());

            return "[" + String.join(",", docs) + "]";
        });

        get("/drivers/:driverid/contacts", (req, res) -> {
            res.type("application/json");
            Random rand = new Random();
            String driverid = String.format("drv%08d", rand.nextInt(NUM_DRIVERS) + 1);

            String dateStr = req.queryParams("fromDate");
            String filterDate = dateStr != null && dateStr.length() >= 8
                    ? String.format("%s-%s-%s", dateStr.substring(0, 4), dateStr.substring(4, 6),
                            dateStr.substring(6, 8))
                    : LocalDate.now().minusDays(30).toString();

            List<String> docs = collection.find(
                    Filters.and(Filters.eq("driver_rating.driver_id", driverid), Filters.gte("timestamp", filterDate)))
                    .map(Document::toJson).into(new ArrayList<>());

            return "[" + String.join(",", docs) + "]";
        });

        post("/contacts/:id/comments", (req, res) -> {
            res.type("application/json");
            Random rand = new Random();
            String id = String.format("cnt%010d", rand.nextInt(NUM_RECORDS) + 1);

            String comment = req.body();
            if (comment == null || comment.trim().isEmpty()) {
                res.status(400);
                return "{\"error\": \"No comment provided\"}";
            }

            try {
                UpdateResult result = collection.updateOne(
                        Filters.eq("contact_id", id),
                        Updates.push("notes", comment));

                if (result.getMatchedCount() == 0) {
                    res.status(404);
                    return String.format("{\"error\": \"Record %s not found\"}", id);
                }

                res.status(200);
                return "{\"status\": \"success\"}";
            } catch (Exception e) {
                res.status(500);
                return String.format("{\"error\": \"%s\"}", escapeJson(e.getMessage()));
            }
        });

        get("/drivers/stats/averages", (req, res) -> {
            res.type("application/json");
            try {
                List<Bson> pipeline = Arrays.asList(
                        Aggregates.group(
                                "$driver_rating.driver_id",
                                Accumulators.avg("average_rating", "$driver_rating.rating"),
                                Accumulators.sum("total_trips", 1)),
                        Aggregates.match(Filters.ne("_id", null)),
                        Aggregates.sort(Sorts.descending("average_rating")));

                List<String> stats = collection.aggregate(pipeline)
                        .map(Document::toJson)
                        .into(new ArrayList<>());

                return "[" + String.join(",", stats) + "]";
            } catch (Exception e) {
                res.status(500);
                return String.format("{\"error\": \"%s\"}", escapeJson(e.getMessage()));
            }
        });

    }

    private static String escapeJson(String text) {
        return text != null ? text.replace("\"", "\\\"").replace("\n", "\\n") : "";
    }
}