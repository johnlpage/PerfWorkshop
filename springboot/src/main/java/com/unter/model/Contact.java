package com.unter.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

@Data
@Document(collection = "contacts")
public class Contact {
    @Id
    private String id;

    @Field("contact_id")
    @JsonProperty("contact_id")
    private String contactId;

    private String timestamp;
    private String date;

    @Field("customer_id")
    @JsonProperty("customer_id")
    private String customerId;

    private Trip trip;
    
    @Field("contact")
    @JsonProperty("contact")
    private ContactInfo contactInfo;

    @Field("star_rating")
    @JsonProperty("star_rating")
    private Integer starRating;

    @Field("driver_rating")
    @JsonProperty("driver_rating")
    private DriverRating driverRating;

    private List<String> notes;
}