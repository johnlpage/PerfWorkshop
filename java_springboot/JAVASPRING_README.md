# Java with Springboot Instructions

# Running the Web service

Open a terminal then 

```
cd /home/ubuntu/java_springboot
```

Build the code

```
mvn clean package
```

Run the service

```
java -jar target/unterservice-1.0.jar

```



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
pkill -f unterservice
```
