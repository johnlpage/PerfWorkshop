#!/usr/bin/env python3
"""
Generate a large JSONL file of taxi service customer contact records.
"""

import json
import random
import sys
from datetime import datetime, timedelta

# Configuration
NUM_RECORDS = 5_000_000  # Adjust as needed
OUTPUT_FILE = "contact_records.json"

# Constants
NUM_CUSTOMERS = 1_000_000
NUM_VEHICLES = 50_000
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
    "item_returned", "fare_adjusted", "escalated_to_manager", None
]

SENTIMENTS = ["very_negative", "negative", "neutral", "positive", "very_positive"]

CITIES = [
    {"city": "New York", "loc_prefix": "NYC"},
    {"city": "Los Angeles", "loc_prefix": "LAX"},
    {"city": "Chicago", "loc_prefix": "CHI"},
    {"city": "Houston", "loc_prefix": "HOU"},
    {"city": "Phoenix", "loc_prefix": "PHX"},
    {"city": "San Francisco", "loc_prefix": "SFO"},
    {"city": "Seattle", "loc_prefix": "SEA"},
    {"city": "Miami", "loc_prefix": "MIA"},
    {"city": "Boston", "loc_prefix": "BOS"},
    {"city": "Denver", "loc_prefix": "DEN"},
    {"city": "Austin", "loc_prefix": "AUS"},
    {"city": "Atlanta", "loc_prefix": "ATL"},
]

VEHICLE_TYPES = ["sedan", "suv", "van", "luxury", "electric", "hybrid", "minivan"]


def generate_records(num_records: int, output_file: str):
    """Generate contact records with ascending dates over the past month."""

    now = datetime.utcnow()
    start_date = now - timedelta(days=30)
    total_seconds = int((now - start_date).total_seconds())

    # Generate sorted random offsets for ascending dates
    print(f"Generating {num_records:,} timestamp offsets...", file=sys.stderr)
    offsets = sorted(random.randint(0, total_seconds) for _ in range(num_records))

    print(f"Writing records to {output_file}...", file=sys.stderr)
    written = 0

    with open(output_file, "w") as f:
        for i, offset in enumerate(offsets):
            record_time = start_date + timedelta(seconds=offset)

            customer_id = f"cst{random.randint(1, NUM_CUSTOMERS):08d}"
            vehicle_id = f"veh{random.randint(1, NUM_VEHICLES):08d}"
            driver_id = f"drv{random.randint(1, NUM_DRIVERS):08d}"
            city_info = random.choice(CITIES)
            location_id = f"{city_info['loc_prefix']}-{random.randint(1, NUM_LOCATIONS):06d}"

            channel = random.choice(CONTACT_CHANNELS)
            reason = random.choice(CONTACT_REASONS)
            status = random.choice(CONTACT_STATUSES)
            sentiment = random.choice(SENTIMENTS)

            # Star rating: weight toward 3-5 but allow 1-2
            star_rating = random.choices(
                population=[1, 2, 3, 4, 5],
                weights=[5, 10, 20, 35, 30],
                k=1
            )[0]

            # Trip length in minutes (most trips 5-60 min, some longer)
            trip_length_minutes = round(random.lognormvariate(2.8, 0.6), 1)
            trip_length_minutes = max(2.0, min(trip_length_minutes, 180.0))

            # Trip distance in miles (correlated loosely with duration)
            avg_speed = random.uniform(8, 35)  # mph in city
            trip_distance_miles = round((trip_length_minutes / 60) * avg_speed, 2)

            # Fare
            base_fare = 2.50
            per_mile = random.uniform(1.50, 3.50)
            per_minute = random.uniform(0.20, 0.50)
            surge = random.choices(
                population=[1.0, 1.25, 1.5, 1.75, 2.0, 2.5],
                weights=[60, 15, 10, 7, 5, 3],
                k=1
            )[0]
            fare_amount = round((base_fare + per_mile * trip_distance_miles + per_minute * trip_length_minutes) * surge, 2)

            # Resolution (only if status is resolved or closed)
            resolution = None
            if status in ("resolved", "closed"):
                resolution = random.choice([r for r in RESOLUTION_TYPES if r is not None])

            # Response time in minutes
            response_time_minutes = round(random.expovariate(1 / 45), 1)  # mean ~45 min
            response_time_minutes = max(1.0, min(response_time_minutes, 1440.0))

            vehicle_type = random.choice(VEHICLE_TYPES)

            record = {
                "contact_id": f"cnt{i + 1:010d}",
                "timestamp": record_time.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                "date": record_time.strftime("%Y-%m-%d"),
                "customer_id": customer_id,
                "trip": {
                    "trip_id": f"trp{random.randint(1, num_records * 2):010d}",
                    "vehicle_id": vehicle_id,
                    "vehicle_type": vehicle_type,
                    "driver_id": driver_id,
                    "start_location_id": location_id,
                    "end_location_id": f"{city_info['loc_prefix']}-{random.randint(1, NUM_LOCATIONS):06d}",
                    "city": city_info["city"],
                    "trip_length_minutes": trip_length_minutes,
                    "trip_distance_miles": trip_distance_miles,
                    "fare_amount": fare_amount,
                    "surge_multiplier": surge,
                },
                "contact": {
                    "channel": channel,
                    "reason": reason,
                    "status": status,
                    "resolution": resolution,
                    "response_time_minutes": response_time_minutes,
                    "sentiment": sentiment,
                },
                "star_rating": star_rating,
                "driver_rating": {
                    "driver_id": driver_id,
                    "rating": star_rating,  # could differ, but let's keep correlated
                    "driver_lifetime_avg_rating": round(random.uniform(3.5, 5.0), 2),
                    "driver_total_trips": random.randint(50, 20000),
                },
            }

            f.write(json.dumps(record) + "\n")
            written += 1

            if written % 100_000 == 0:
                print(f"  ...{written:,} records written", file=sys.stderr)

    print(f"Done! {written:,} records written to {output_file}", file=sys.stderr)


if __name__ == "__main__":
    num = int(sys.argv[1]) if len(sys.argv) > 1 else NUM_RECORDS
    out = sys.argv[2] if len(sys.argv) > 2 else OUTPUT_FILE
    generate_records(num, out)
