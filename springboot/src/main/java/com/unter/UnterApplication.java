package com.unter;

import com.mongodb.client.MongoCollection;
import com.mongodb.client.model.IndexOptions;
import com.mongodb.client.model.Indexes;
import jakarta.annotation.PostConstruct;
import org.bson.Document;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.mongodb.core.MongoTemplate;

@SpringBootApplication
public class UnterApplication {

    private final MongoTemplate mongoTemplate;

    public UnterApplication(MongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    public static void main(String[] args) {
        SpringApplication.run(UnterApplication.class, args);
    }

    @PostConstruct
    public void initIndexes() {
        MongoCollection<Document> collection = mongoTemplate.getCollection("contacts");
        collection.createIndex(Indexes.ascending("contact_id"), new IndexOptions().unique(true));
        collection.createIndex(Indexes.ascending("customer_id"));
        collection.createIndex(Indexes.ascending("driver_rating.driver_id"));
        
        System.out.println("Connected to MongoDB! Documents: " + collection.estimatedDocumentCount());
    }
}