# CREATE DATABASE TABLES:
# CREATE TABLE `sensors` (`id` varchar(255) NOT NULL,`name` varchar(255) NOT NULL);
# CREATE TABLE `sensor_log` (`id` int(11) NOT NULL,`timestamp_insertion` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),`sensor_id` varchar(255) NOT NULL,`timestamp` timestamp NOT NULL DEFAULT current_timestamp(),`lastseen` int(11) NOT NULL,`lowbattery` tinyint(1) NOT NULL,`temp_celsius` float NOT NULL,`humidity` float DEFAULT NULL);

import time
import requests
import mysql.connector

#######################
# VARS
#######################

# enter specific phoneid for API
phoneId = "123456789123"

# enter database credentials
db_config = {
    "host": "localhost",
    "user": "user",
    "password": "password",
    "database": "sensors"
}

# enter sensor id's separated by commas. WITHOUT! a space!
sensorsString = "154KU87F4G9S,154KU87F4G9S,154KU87F4G9S"

# enter api endpoint
api = "https://www.data199.com/api/pv1/device/lastmeasurement"

#######################
# SCRIPT
#######################

# setup mysql connection
conn = mysql.connector.connect(**db_config)
cursor = conn.cursor()

# setup http 
http_headers = {
  'Content-Type': 'application/x-www-form-urlencoded'
}

# UNIX timestamp (sec)
now = int(time.time())

# post request to sensors api
payload = "deviceids={}&phoneid={}".format(sensorsString, phoneId)
response = (requests.request("POST", api, headers=http_headers, data=payload))

print("Successfully retrieved data from api.")

responseJson = response.json()

sensors = responseJson["devices"]

for sensor in sensors:
  sensorId = sensor["deviceid"]
  lastseen = sensor["lastseen"]
  lowbattery = sensor["lowbattery"]
  timestamp = sensor["measurement"]["ts"]
  temp = sensor["measurement"]["t1"]

  # some sensors only sens for temperature and not for humidity
  try:
    humidity = sensor["measurement"]["h"]
  except:
    humidity = False

  # write to DB
  try:
    if humidity:
      sql = "INSERT INTO sensor_log (sensor_id, timestamp_insertion, timestamp, lastseen, lowbattery, temp_celsius, humidity) VALUES (%s, %s, %s, %s, %s, %s, %s)"
      data = (sensorId, now, timestamp, lastseen, lowbattery, temp, humidity)
    else:
      sql = "INSERT INTO sensor_log (sensor_id, timestamp_insertion, timestamp, lastseen, lowbattery, temp_celsius) VALUES (%s, %s, %s, %s, %s, %s)"
      data = (sensorId, now, timestamp, lastseen, lowbattery, temp)

    cursor.execute(sql, data)
    conn.commit()

    print("Done sensor: {}\t t:{} h:{}".format(sensorId, temp, humidity if humidity else "N/A"))
  except mysql.connector.Error as error:
    print("MYSQL Error: {}".format(error))

cursor.close()
conn.close()
