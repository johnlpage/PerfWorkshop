# Load Sample Data

`$MONGODB_URI` is already configured in your environment

```bash
mongoimport -d unter -c contacts -j 4 --uri $MONGODB_URI --file contact_records.json --drop

```
# Launch Service in Language of your choice

See instructions in Language directories


# Run Testharness

```bash
cd /home/ubuntu
bash testharness.sh
```

# Connect with mongosh

```bash
mongosh $MONGODB_URI
```