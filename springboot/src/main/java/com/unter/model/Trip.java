package com.unter.model;

import lombok.Data;
import org.springframework.data.mongodb.core.mapping.Field;
import com.fasterxml.jackson.annotation.JsonProperty;

@Data
public class Trip {
    @Field("trip_id") @JsonProperty("trip_id") private String tripId;
    @Field("vehicle_id") @JsonProperty("vehicle_id") private String vehicleId;
    @Field("vehicle_type") @JsonProperty("vehicle_type") private String vehicleType;
    @Field("driver_id") @JsonProperty("driver_id") private String driverId;
    @Field("start_location_id") @JsonProperty("start_location_id") private String startLocationId;
    @Field("end_location_id") @JsonProperty("end_location_id") private String endLocationId;
    private String city;
    @Field("trip_length_minutes") @JsonProperty("trip_length_minutes") private Double tripLengthMinutes;
    @Field("trip_distance_miles") @JsonProperty("trip_distance_miles") private Double tripDistanceMiles;
    @Field("fare_amount") @JsonProperty("fare_amount") private Double fareAmount;
    @Field("surge_multiplier") @JsonProperty("surge_multiplier") private Double surgeMultiplier;
}