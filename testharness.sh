#!/bin/bash


if command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
else
    TIMEOUT_CMD="timeout"
fi

# Configuration
URL_BASE="http://127.0.0.1:5050"
URL_contacts="${URL_BASE}/contacts"
URL_PING="${URL_BASE}/ping"
DATA_FILE="contact_records.json"
#Stop any test after 1 minute 
MAX_TIME=60

#Increase this if you get this done in seconds
NUM_REQUESTS=10000

echo "-------------------------------------------------------"
echo "Step 0: Pre-flight Check (Service Availability)"
echo "-------------------------------------------------------"

if ! curl --silent --head --fail --max-time 5 "$URL_PING" > /dev/null; then
    echo "[!] CRITICAL ERROR: Service at $URL_PING is unreachable."
    echo "[!] Aborting all tests."
    exit 1
fi

echo "[+] Service is UP. Proceeding with benchmarks..."


echo -e "\n-------------------------------------------------------"
echo "Step 1: Micro Batch File Upload (Single Request)"
echo "-------------------------------------------------------"

# --max-time (or -m) handles the timeout natively within curl
# Exit code 28 is the specific code for a timeout
time -p curl -X POST \
  -T "$DATA_FILE.small" \
  -H "Transfer-Encoding: chunked" \
  -H "Content-Type: application/octet-stream" \
  --max-time ${MAX_TIME} \
  --progress-bar \
  "$URL_contacts"

RESULT=$?

if [ $RESULT -eq 28 ]; then
    echo -e "\n[!] ERROR: Upload exceeded ${MAX_TIME}s limit (Curl Timeout)."
elif [ $RESULT -ne 0 ]; then
    echo -e "\n[!] ERROR: Curl failed with exit code $RESULT."
else
    echo -e "\n[+] Upload completed successfully."
fi

echo -e "\n-------------------------------------------------------"
echo "Step 2: Large Initial File Upload (Single Request)"
echo "-------------------------------------------------------"


# --max-time (or -m) handles the timeout natively within curl
# Exit code 28 is the specific code for a timeout
$TIMEOUT_CMD ${MAX_TIME}s time -p curl -X POST \
  -T "$DATA_FILE.large" \
  -H "Transfer-Encoding: chunked" \
  -H "Content-Type: application/octet-stream" \
  --max-time ${MAX_TIME} \
  --progress-bar \
  "$URL_contacts"

RESULT=$?

if [ $RESULT -eq 28 ]; then
    echo -e "\n[!] ERROR: Upload exceeded ${MAX_TIME}s limit (Curl Timeout)."
elif [ $RESULT -ne 0 ]; then
    echo -e "\n[!] ERROR: Curl failed with exit code $RESULT."
else
    echo -e "\n[+] Upload completed successfully."
fi

echo -e "\n-------------------------------------------------------"
echo "Step 3: Testing fetching recent contacts from customer"
echo "-------------------------------------------------------"


# -s defines the timeout per individual request
BY_CUSTOMER="$URL_BASE/customers/cstXXXXXX/contacts"
$TIMEOUT_CMD ${MAX_TIME}s ab -n $NUM_REQUESTS -c 20 -l -s ${MAX_TIME} "$BY_CUSTOMER"

RESULT=$?

if [ $RESULT -eq 124 ]; then
    echo -e "\n[!] ERROR: Benchmark timed out before completing $NUM_REQUESTS requests."
else
    echo -e "\n[+] Benchmark finished (completed $NUM_REQUESTS requests or server closed connection)."
fi



echo -e "\n-------------------------------------------------------"
echo "Step 3: Testing fetching recent contacts about driver"
echo "-------------------------------------------------------"


# -s defines the timeout per individual request
BY_DRIVER="$URL_BASE/drivers/drvXXXXXX/contacts"

$TIMEOUT_CMD ${MAX_TIME}s ab -n $NUM_REQUESTS -c 20 -l -s ${MAX_TIME} "$BY_DRIVER"

RESULT=$?

if [ $RESULT -eq 124 ]; then
    echo -e "\n[!] ERROR: Benchmark timed out before completing $NUM_REQUESTS requests."
else
    echo -e "\n[+] Benchmark finished (completed $NUM_REQUESTS requests or server closed connection)."
fi


echo -e "\n-------------------------------------------------------"
echo "Step 3: Testing adding random comments to contacts"
echo "-------------------------------------------------------"


# -s defines the timeout per individual request
COMMENT_URL="$URL_BASE/contacts/id/comments"
echo "Comment: This test simulates adding random comments to contacts" > comment.txt
$TIMEOUT_CMD ${MAX_TIME}s ab -n $NUM_REQUESTS -c 20  -p comment.txt  -T "application/json" $COMMENT_URL

RESULT=$?

if [ $RESULT -eq 124 ]; then
    echo -e "\n[!] ERROR: Benchmark timed out before completing $NUM_REQUESTS requests."
else
    echo -e "\n[+] Benchmark finished (completed $NUM_REQUESTS requests or server closed connection)."
fi

echo -e "\n-------------------------------------------------------"
echo "Step 4: Driver Rating Averages (Aggregation Performance)"
echo "-------------------------------------------------------"

STATS_URL="$URL_BASE/drivers/stats/averages"
ITERATIONS=5
TOTAL_TIME=0

for i in $(seq 1 $ITERATIONS); do
    # Get time_total in seconds (e.g., 0.452)
    TIME=$(curl -s -o /dev/null -w "%{time_total}" "$STATS_URL")
    
    # Convert to ms for readability
    MS=$(echo "$TIME * 1000 / 1" | bc)
    echo "Run $i: ${MS}ms"
    
    TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
done

AVG=$(echo "scale=3; ($TOTAL_TIME / $ITERATIONS) * 1000" | bc)
echo -e "\n[+] Mean Aggregation Time: ${AVG}ms"

echo -e "\n-------------------------------------------------------"
echo "All tests finished."
