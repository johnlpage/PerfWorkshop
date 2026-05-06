package com.unter.repository;

import com.unter.model.Contact;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ContactRepository extends MongoRepository<Contact, String> {
    
    // Spring automatically generates the queries for these based on the method name
    List<Contact> findByCustomerIdAndTimestampGreaterThanEqual(String customerId, String timestamp);
    
    List<Contact> findByDriverRatingDriverIdAndTimestampGreaterThanEqual(String driverId, String timestamp);
}