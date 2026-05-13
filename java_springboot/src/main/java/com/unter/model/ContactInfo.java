package com.unter.model;

import lombok.Data;
import org.springframework.data.mongodb.core.mapping.Field;
import com.fasterxml.jackson.annotation.JsonProperty;

@Data
public class ContactInfo {
    private String channel;
    private String reason;
    private String status;
    private String resolution;
    @Field("response_time_minutes") @JsonProperty("response_time_minutes") private Double responseTimeMinutes;
    private String sentiment;
}