#!/bin/bash

# Configuration
URL_BASE="http://localhost:5050"
URL_EVENTS="${URL_BASE}/events"
URL_PING="${URL_BASE}/ping"
DATA_FILE="contact_records.json"
MAX_TIME=60

echo "-------------------------------------------------------"
echo "Step 0: Pre-flight Check (Service Availability)"
echo "-------------------------------------------------------"

# Use curl to check if the service is up. 
# --silent (no output), --head (just headers), --fail (exit non-zero on 4xx/5xx)
if ! curl --silent --head --fail "$URL_PING" > /dev/null; then
    echo "[!] CRITICAL ERROR: Service at $URL_PING is unreachable."
    echo "[!] Aborting all tests."
    exit 1
fi

echo "[+] Service is UP. Proceeding with benchmarks..."

echo -e "\n-------------------------------------------------------"
echo "Step 1: Large File Upload (Single Request)"
echo "-------------------------------------------------------"

# Wrap 'time' and 'curl' in the 'timeout' command.
timeout ${MAX_TIME}s time -p curl -X POST \
  -T "$DATA_FILE" \
  -H "Transfer-Encoding: chunked" \
  -H "Content-Type: application/octet-stream" \
  --progress-bar \
  "$URL_EVENTS"

# Capture the exit status of the previous command
RESULT=$?

if [ $RESULT -eq 124 ]; then
    echo -e "\n[!] ERROR: Upload exceeded ${MAX_TIME}s and was killed."
elif [ $RESULT -ne 0 ]; then
    echo -e "\n[!] ERROR: Curl failed with exit code $RESULT."
else
    echo -e "\n[+] Upload completed successfully."
fi

echo -e "\n-------------------------------------------------------"
echo "Step 2: High Concurrency Ping (Apache Benchmark)"
echo "-------------------------------------------------------"

# -s defines the timeout per request in ab (in seconds)
# timeout wraps the entire execution
timeout ${MAX_TIME}s ab -n 10000 -c 20 -s $MAX_TIME "$URL_PING"

if [ $? -eq 124 ]; then
    echo -e "\n[!] ERROR: Benchmark exceeded ${MAX_TIME}s total and was killed."
else
    echo -e "\n[+] Benchmark completed."
fi

echo -e "\n-------------------------------------------------------"
echo "All tests finished."