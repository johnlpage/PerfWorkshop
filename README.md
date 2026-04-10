 To run the test

```
# Stream JSON file to POST endpoint  
time curl -X POST -H "Content-Type: application/json" -d @data.json http://localhost:8080/load  
  
# Then hammer a GET endpoint: 10,000 requests, 20 concurrent  
# Probably already installed  
ab -n 10000 -c 20 http://localhost:5050/ping  
```
