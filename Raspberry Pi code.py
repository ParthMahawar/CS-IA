import smbus
import time
import random
from picamera import PiCamera

import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from firebase_admin import storage
from pyfcm import FCMNotification as noti

from datetime import datetime

service = noti(api_key='*Key removed for security purposes*')

address = 0x48#Pin on RasPi
A0 = 0x40 #Pin on ADC
A1 = 0x41
print(A0)

camera = PiCamera()

cred = credentials.Certificate("credentials.json")#Credentials to modify database 
#													Not there on GitHub for security purposes
firebase_admin.initialize_app(cred,{
    'projectId': "fire-notifier-17111",
    'storageBucket': 'fire-notifier-17111.appspot.com'
    })

db = firestore.client()
collection = db.collection(u'datapoints')#Database collection storing the last 10 minutes' data

othercol = db.collection(u'laststuf')#stores final datapoint

alertcol = db.collection(u'lastalert')#stores last alert

counter = 0;

bus = smbus.SMBus(1)
while True:
    bus.write_byte(address,A1)
    value = bus.read_byte(address)
    print("Smoke", value)#Obtains Smoke value
    
    bus.write_byte(address, A0)
    value2 = bus.read_byte(address)
    print(value2)#Obtains LPG Value
    
    collection.document(str(counter%600)).set({
        u'Smoke' : value,
        u'LPG' : value2,
        u'time' : datetime.now()
    })#Adds value to database, overwriting the value from ten minutes ago
    
    othercol.document(u'main').set({
        u'Smoke' : value,
        u'LPG' : value2
    })#Sets last datapoint to same
    
    if value > 135 or value2 > 135:#This block sends a notification to the client when High levels of LPG are detected, and uploads a photo as well
        if value > 135 and value2 > 135:
            title = "High Smoke and LPG detected"
            body = "Smoke level of {}\n".format(value) + "LPG level of {} detected".format(value)
        elif value > 135:
            title = "High Smoke detected"
            body = "Smoke level of {} detected".format(value)
        else:
            title = "High LPG detected"
            body = "LPG level of {} detected".format(value2)
        
        result = service.notify_topic_subscribers(topic_name="global", message_body=body, message_title = title)
        print(result)
        
        camera.start_preview()
        time.sleep(2)#Camera needs time to startup
        camera.capture("image.jpg")
        
        bucket = storage.bucket()
        
        img_dat = open("image.jpg", "rb").read()
        blob = bucket.blob("lastalert.jpg")
        
        blob.upload_from_string(
            img_dat,
            content_type = "image/jpg"
        )
        
        alertcol.document(u"main").set({
            u'Smoke' : value,
            u'LPG' : value2,
            u'time' : datetime.now(),
        })
      
    counter += 1
    #No time.sleep is needed since it's been found that each loop takes about one second to complete anyway
