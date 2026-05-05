 # Python Instructions

# Running the Web service

Open a terminal, change to the correct directory and typ `python service.py`
You can also run it in vs code by clicking the 'Play' Arrow at the top right

#Running the testharness

# Running the test harness

Open a terminal and change to the /home/ubuntu directory and type
 `python testharness.py` you can  also run it in vs code but be aware that
 you MUST use the option to run in seperate terminal otherwise it will try to 
 reuse the terminal your web service is in and not start.
 
# Killing a disconneted serice

If its still running but not attached to a terminal, open a terminal and run

```
pkill -f service.py
```
