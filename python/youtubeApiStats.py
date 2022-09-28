import requests
import json

apikey = "<key>"
channelId = "<id>"

apiPath = "https://www.googleapis.com/youtube/v3"

def apiGet(path, params):
    req = requests.get(apiPath + path, 
        headers = {
            "X-goog-api-key": apikey,
            "Content-Type": "application/json"
        },
        params = params
    )

    jsonData = req.json()
    responseCode = req.status_code

    return jsonData

data = apiGet("/channels", {"part": "statistics", "id": channelId})

viewCount = data['items'][0]['statistics']['viewCount']
subCount = data['items'][0]['statistics']['subscriberCount']
videoCount = data['items'][0]['statistics']['videoCount']

print(viewCount, subCount, videoCount)
