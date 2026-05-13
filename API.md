## API Endpoints  
  
Each webservice supports the following endpoints:  

**To aid testing the service itself will choose values regardless of what URL contains**
  
| Method | Endpoint | Description |  
|:---|:---|:---|  
| `GET` | `/ping` | Check the service is up |  
| `POST` | `/contacts` | Insert one or more contact records via line-stream |  
| `GET` | `/contacts/<id>` | Fetch a contact by MongoDB ObjectId |  
| `GET` | `/customers/<custid>/contacts` | Fetch contacts for a specific (or random) customer |  
| `GET` | `/drivers/<driverid>/contacts` | Fetch contacts for a specific (or random) driver |  
| `POST` | `/contacts/:id/comments` | Add a comment/note to a specific contact record |  
| `GET` | `/drivers/stats/averages` | Get aggregate rating and trip stats for all drivers |
