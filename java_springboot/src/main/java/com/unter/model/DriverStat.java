package com.unter.model;

import lombok.Data;
import org.springframework.data.annotation.Id;

@Data
public class DriverStat {
    @Id
    private String driverId;
    private Double averageRating;
    private Integer totalTrips;
}