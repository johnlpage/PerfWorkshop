## API Endpoints  
  
Each webservice supports the following endpoints:  
  
| Method | Endpoint | Description |  
|--------|----------|-------------|  
| `GET` | `/ping` | Check the service is up |  
| `POST` | `/things` | Insert one or more thing records |  
| `PUT` | `/things` | Replace one or more thing records |  
| `PATCH` | `/things` | Update part of one or more thing records |  
| `GET` | `/things/<id>` | Fetch a thing by ID |  
| `GET` | `/customers/<custid>/things?limit=10` | Fetch things for a specific customer |  

  
## Getting Started  
  
First, call `/ping` to verify your service is up and that  
[Apache Benchmark (ab)](https://httpd.apache.org/docs/2.4/programs/ab.html) —  
a super lightweight, C-based benchmarking tool — is working.  

```
ab -n 10000 -c 20 http://localhost:5050/ping  
```

Empty Out the collection(s) use are using either in code or with Atlas/mongosh
Then Bulk load the supplied data to see how it goes. Note the time it takes
you wanto load as fast as possible (but the data needs to work in the next few tests too

```
time curl -X POST -H "Content-Type: application/json" -d @data.json http://localhost:8080/load  
```
