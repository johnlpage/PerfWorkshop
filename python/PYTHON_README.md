 # Python Instructions

# Running the Web service

Open a terminal then

```
cd /home/ubuntu/python
python service.py
```

You can also run it in vs code by clicking the 'Play' Arrow at the top right

# Stopping the python service

Type Control+C in the window in which it is running


# Running the test harness

Open a second terminal then

```
cd /home/ubuntu
bash testharness.sh
```

 
# Killing a disconneted serice

If its still running but not attached to a terminal, open a terminal and run

```
pkill -f service.py
```
