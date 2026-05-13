#!/usr/bin/env python3
"""
Generate a large JSONL file of taxi service customer contact records.
EXTREME SPEED VERSION (Single Process): Bypasses json library and complex math.
"""

import random
import sys
from datetime import datetime, timedelta, timezone

# --- CONFIGURATION DEFAULTS ---
NUM_RECORDS = 5_000_000
OUTPUT_FILE = "contact_records.json"
START_ID = 1

# --- CONSTANTS ---
NUM_CUSTOMERS = 400_000
NUM_VEHICLES = 20_000
NUM_DRIVERS = 25_000
NUM_LOCATIONS = 10_000

CONTACT_CHANNELS = ["phone", "email", "in_app_chat", "sms", "social_media", "web_form"]
CONTACT_REASONS = [
    "billing_dispute", "lost_item", "driver_complaint", "driver_compliment",
    "route_issue", "app_problem", "safety_concern", "fare_estimate",
    "cancellation", "wait_time", "vehicle_condition", "payment_failure",
    "promo_code_issue", "accessibility_request", "general_inquiry",
    "trip_feedback", "refund_request", "account_issue"
]
CONTACT_STATUSES = ["open", "in_progress", "resolved", "escalated", "closed"]
RESOLUTION_TYPES = [
    "refund_issued", "credit_applied", "apology_sent", "driver_warned",
    "driver_suspended", "no_action_needed", "technical_fix_applied",
    "item_returned", "fare_adjusted", "escalated_to_manager"
]
SENTIMENTS = ["very_negative", "negative", "neutral", "positive", "very_positive"]

CITIES = [
    {"city": "New York", "loc_prefix": "NYC", "base_lat": 40.7128, "base_lon": -74.0060},
    {"city": "Los Angeles", "loc_prefix": "LAX", "base_lat": 34.0522, "base_lon": -118.2437},
    {"city": "Chicago", "loc_prefix": "CHI", "base_lat": 41.8781, "base_lon": -87.6298},
    {"city": "Houston", "loc_prefix": "HOU", "base_lat": 29.7604, "base_lon": -95.3698},
    {"city": "Phoenix", "loc_prefix": "PHX", "base_lat": 33.4484, "base_lon": -112.0740},
    {"city": "San Francisco", "loc_prefix": "SFO", "base_lat": 37.7749, "base_lon": -122.4194},
    {"city": "Seattle", "loc_prefix": "SEA", "base_lat": 47.6062, "base_lon": -122.3321},
    {"city": "Miami", "loc_prefix": "MIA", "base_lat": 25.7617, "base_lon": -80.1918},
    {"city": "Boston", "loc_prefix": "BOS", "base_lat": 42.3601, "base_lon": -71.0589},
    {"city": "Denver", "loc_prefix": "DEN", "base_lat": 39.7392, "base_lon": -104.9903},
    {"city": "Austin", "loc_prefix": "AUS", "base_lat": 30.2672, "base_lon": -97.7431},
    {"city": "Atlanta", "loc_prefix": "ATL", "base_lat": 33.7490, "base_lon": -84.3880},
]
VEHICLE_TYPES = ["sedan", "suv", "van", "luxury", "electric", "hybrid", "minivan"]

# --- SPEEDUP TABLES ---
STAR_POOL = [1]*5 + [2]*10 + [3]*20 + [4]*35 + [5]*30
SURGE_POOL = [1.0]*60 + [1.25]*15 + [1.5]*10 + [1.75]*7 + [2.0]*5 + [2.5]*3

# MODIFIED: Acceleration event counts increased by 50%
# (e.g. 10 -> 15, 40 -> 60)
TELEMETRY_COUNT_POOL = [0]*2 + [8]*5 + [15]*15 + [23]*8 + [30]*5 + [45]*3 + [60]*2


def generate_records(num_records: int, output_file: str, start_id: int):
    print(f"Generating {num_records:,} records (starting ID: {start_id}) to '{output_file}'...", file=sys.stderr)
    
    random.seed()
    now = datetime.now(timezone.utc)
    start_date = now - timedelta(days=365)
    total_seconds = int((now - start_date).total_seconds())

    # Localized functions for extreme speed
    randint = random.randint
    choice = random.choice
    uniform = random.uniform

    write_buffer = []
    BUFFER_SIZE = 20_000
    written = 0

    with open(output_file, "w", encoding="utf-8") as f:
        for i in range(num_records):
            # Fast basic math
            offset = randint(0, total_seconds)
            record_time = start_date + timedelta(seconds=offset)
            record_iso = record_time.isoformat(timespec='milliseconds').replace('+00:00', 'Z')
            date_iso = str(record_time.date())

            city_info = choice(CITIES)
            loc_prefix = city_info['loc_prefix']
            status = choice(CONTACT_STATUSES)
            
            trip_length_minutes = randint(2, 60)
            avg_speed = randint(10, 35)
            trip_distance_miles = (trip_length_minutes / 60) * avg_speed
            fare_amount = (2.50 + (uniform(1.5, 3.5) * trip_distance_miles) + (0.35 * trip_length_minutes)) * choice(SURGE_POOL)

            res_str = f'"{choice(RESOLUTION_TYPES)}"' if status in ("resolved", "closed") else "null"

            num_telemetry_points = choice(TELEMETRY_COUNT_POOL)
            telemetry_strs = []
            
            if num_telemetry_points > 0:
                trip_start_time = record_time - timedelta(minutes=trip_length_minutes)
                interval_seconds = max(1, (trip_length_minutes * 60) // num_telemetry_points)
                base_lat = city_info["base_lat"]
                base_lon = city_info["base_lon"]

                for t_idx in range(num_telemetry_points):
                    event_time = trip_start_time + timedelta(seconds=(t_idx * interval_seconds))
                    iso_time = event_time.isoformat(timespec='milliseconds').replace('+00:00', 'Z')
                    
                    x_accel = uniform(-6.5, 5.0)
                    y_accel = uniform(-3.5, 3.5)
                    z_accel = uniform(8.5, 11.0)
                    lat = base_lat + uniform(-0.15, 0.15)
                    lon = base_lon + uniform(-0.15, 0.15)

                    telemetry_strs.append(
                        f'{{"ts":"{iso_time}","x":{x_accel:.3f},"y":{y_accel:.3f},"z":{z_accel:.3f},"lat":{lat:.5f},"lon":{lon:.5f}}}'
                    )

            telemetry_json = "[" + ",".join(telemetry_strs) + "]"
            
            # UPDATED: Current ID is start_id + current iteration
            current_contact_id = start_id + i
            star = choice(STAR_POOL)

            record_str = (
                f'{{"contact_id":"cnt{current_contact_id:010d}","timestamp":"{record_iso}","date":"{date_iso}",'
                f'"customer_id":"cst{randint(1, NUM_CUSTOMERS):08d}","trip":{{"trip_id":"trp{randint(1, NUM_RECORDS * 2):010d}",'
                f'"vehicle_id":"veh{randint(1, NUM_VEHICLES):08d}","vehicle_type":"{choice(VEHICLE_TYPES)}",'
                f'"driver_id":"drv{randint(1, NUM_DRIVERS):08d}","start_location_id":"{loc_prefix}-{randint(1, NUM_LOCATIONS):06d}",'
                f'"end_location_id":"{loc_prefix}-{randint(1, NUM_LOCATIONS):06d}","city":"{city_info["city"]}",'
                f'"trip_length_minutes":{trip_length_minutes},"trip_distance_miles":{trip_distance_miles:.2f},'
                f'"fare_amount":{fare_amount:.2f},"surge_multiplier":{choice(SURGE_POOL)},"acceleration_events":{telemetry_json}}},'
                f'"contact":{{"channel":"{choice(CONTACT_CHANNELS)}","reason":"{choice(CONTACT_REASONS)}","status":"{status}",'
                f'"resolution":{res_str},"response_time_minutes":{randint(1, 120)},"sentiment":"{choice(SENTIMENTS)}"}},'
                f'"star_rating":{star},"driver_rating":{{"driver_id":"drv{randint(1, NUM_DRIVERS):08d}","rating":{star},'
                f'"driver_lifetime_avg_rating":{uniform(3.5, 5.0):.2f},"driver_total_trips":{randint(50, 20000)}}}}}'
            )

            write_buffer.append(record_str)
            written += 1

            if len(write_buffer) >= BUFFER_SIZE:
                f.write("\n".join(write_buffer) + "\n")
                write_buffer.clear()
                
            if written % 250_000 == 0:
                 print(f"  ...{written:,} records generated", file=sys.stderr)

        if write_buffer:
            f.write("\n".join(write_buffer) + "\n")

    print(f"Done! {num_records:,} records written to {output_file}", file=sys.stderr)


if __name__ == "__main__":
    # Usage: script.py [num_records] [outfile] [start_id]
    num = int(sys.argv[1]) if len(sys.argv) > 1 else NUM_RECORDS
    out = sys.argv[2] if len(sys.argv) > 2 else OUTPUT_FILE
    start = int(sys.argv[3]) if len(sys.argv) > 3 else START_ID
    
    generate_records(num, out, start)