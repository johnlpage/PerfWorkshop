package com.unter.model;

import lombok.Data;
import org.springframework.data.mongodb.core.mapping.Field;
import com.fasterxml.jackson.annotation.JsonProperty;

@Data
public class DriverRating {
    @Field("driver_id") @JsonProperty("driver_id") private String driverId;
    private Integer rating;
    @Field("driver_lifetime_avg_rating") @JsonProperty("driver_lifetime_avg_rating") private Double driverLifetimeAvgRating;
    @Field("driver_total_trips") @JsonProperty("driver_total_trips") private Integer driverTotalTrips;
}