import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() => runApp(MainApp());

class MainApp extends StatelessWidget {//Routine Android development stuff
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Homepage(title: "Details"),
    );
  }
}

class Homepage extends StatefulWidget {
  Homepage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();//Initializes Notification Listener

  @override
  void initState() {
    super.initState();
    FCMStuff();
  }//Runs below function when app is opened

  void FCMStuff(){//Configures notification listener
    _firebaseMessaging.getToken().then((token){
      print(token);
    });

    _firebaseMessaging.configure(//Mainly debug code, but this needs to be configured to properly allow android to handle notifications
      onMessage: (Map<String, dynamic> message) async {
        print('on message $message');
        Navigator.of(context).push(MaterialPageRoute( builder: (context) => AlertPage()));
      },
      onResume: (Map<String, dynamic> message) async {
        print('on resume $message');
      },
      onLaunch: (Map<String, dynamic> message) async {
        print('on launch $message');
      },
    );

    _firebaseMessaging.subscribeToTopic("global");//Makes phone display notifications sent to topic "global", which is where the device will send them
  }

  @override
  Future<List<List>> getData() async{//Gets data from database
    final databaseReference = Firestore.instance;
    List<List> lst = [<FlSpot>[],<FlSpot>[]];

    var stuff = await databaseReference.collection("datapoints").orderBy("time").getDocuments();
    Timestamp now = Timestamp.now();
    stuff.documents.forEach((f){
      Timestamp time = f.data["time"];
      print(time);
      int smoke = f.data["Smoke"];
      int lpg = f.data["LPG"];

      int diff = (now.seconds-time.seconds);
      lst[0].add(FlSpot(diff.toDouble(), smoke.toDouble()));
      lst[1].add(FlSpot(diff.toDouble(), lpg.toDouble()));
    });
    lst.add(await finalDP());
    return lst;
  }

  Future finalDP() async{//Gets final datapoint
    final databaseReference = Firestore.instance;
    var stuff = await databaseReference.collection("laststuf").getDocuments();

    List lst = [];

    stuff.documents.forEach((f){
      lst.add(f.data["Smoke"]/256);
      lst.add(f.data["LPG"]/256);
      print(f.data);
    });

    return lst;
  }

  Future getAlert() async{
    final databaseReference = Firestore.instance;
    var stuff = await databaseReference.collection("lastalert").document("main").get();
    return stuff.data;
  }

  Future DisplayAlert() async{
      var alert = await getAlert();
      Timestamp alerttime = alert["time"];
      return Padding(
        padding: EdgeInsets.all(10.0),
        child: InkWell(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.all(Radius.circular(5.0)),
              color: Colors.red,
            ),
            child: Text(
              "Alert Recieved at " + alerttime.toDate().toIso8601String(),
              style: TextStyle(color: Colors.white)
            ),
          ),
          onTap: () {Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AlertPage())
          );}),
      );
  }

  Future createUI(List<List> spots) async{
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(3.5),
            ),
            await DisplayAlert(),
            Container(
              padding: EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Column(children: <Widget>[
                Text(
                  "Smoke Level",
                ),
                Container(height: 5.0, width: 0.0),
                LinearPercentIndicator(
                  lineHeight: 14.0,
                  percent: spots[2][0],
                  backgroundColor: Colors.grey,
                  progressColor: Colors.blue,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 15, 28, 5),
                  child: SizedBox(
                    height: 180,
                    width: 350,
                    child: FlChart(
                      chart: LineChart(LineChartData(
                        titlesData: FlTitlesData(
                          bottomTitles:
                          SideTitles(showTitles: false)),
                        minY: 0,
                        clipToBorder: true,
                        lineBarsData: [
                          LineChartBarData(
                            preventCurveOverShooting: true,
                            isCurved: true,
                            spots: spots[0],
                            dotData: FlDotData(show: false))
                        ]))))),

                Text("Graph for last 10 minutes"),
              ])),
            Container(
              height: 7.0,
            ),
            Container(
              padding: EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.all(Radius.circular(5))),
              child: Column(children: <Widget>[
                Text(
                  "LPG Level",
                ),
                Container(height: 5.0, width: 0.0),
                LinearPercentIndicator(
                  lineHeight: 14.0,
                  percent: spots[2][1],
                  backgroundColor: Colors.grey,
                  progressColor: Colors.blue,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 15, 28, 5),
                  child: SizedBox(
                    height: 180,
                    width: 350,
                    child: FlChart(
                      chart: LineChart(LineChartData(
                        minY: 0,
                        titlesData: FlTitlesData(
                          bottomTitles:
                          SideTitles(showTitles: false)),
                        clipToBorder: true,
                        lineBarsData: [
                          LineChartBarData(
                            preventCurveOverShooting: true,
                            isCurved: true,
                            spots: spots[1],
                            dotData: FlDotData(show: false))
                        ]))))),
                Text("Graph for last 10 minutes")
              ]))
          ],
        ),
      ));
  }


  Widget build(BuildContext context) {
    var spots = getData();
    print(spots);
    return FutureBuilder(
      future: getData(),
      builder: (BuildContext context, AsyncSnapshot snapshot){
        if(snapshot.hasData){
          return FutureBuilder(
            future: createUI(snapshot.data),
            builder: (BuildContext context, AsyncSnapshot snapshot){
              if(snapshot.hasData){
                return snapshot.data;
              }
              else if(snapshot.hasError){
                return Text(snapshot.error.toString());
              }
              else{
                return CircularProgressIndicator();
              }
          },
          );
        }
        else if(snapshot.hasError){
          return Text("error");
        }
        else{
          return CircularProgressIndicator();
        }
      }
    );
  }
}

class AlertPage extends StatelessWidget {
  Future getAlert() async{
    final databaseReference = Firestore.instance;
    var stuff = await databaseReference.collection("lastalert").document("main").get();
    return stuff.data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getAlert(
      ),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return BuildUI(snapshot.data);
        }
        else if (snapshot.hasError){
          return Text("error");
        }
        else{
          return CircularProgressIndicator();
        }
      },
    );
  }
  Widget BuildUI(data) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: Text(
          "Alert"
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(
          10.0
        ),
        child: Column(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(
                    5.0
                  )
                )
              ),
              padding: EdgeInsets.all(
                5.0
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          "Alert Time",
                          style: TextStyle(
                            fontWeight: FontWeight.bold
                          ),
                        )
                      ),
                      Text(
                        data["time"].toDate().toIso8601String(),
                        textAlign: TextAlign.end,
                      )
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          "Smoke Level",
                          style: TextStyle(
                            fontWeight: FontWeight.bold
                          ),
                        )
                      ),
                      Text(
                        data["Smoke"].toString()
                      )
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          "LPG Level",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ),
                      Text(
                        data["LPG"].toString(),
                      )
                    ],
                  )
                ],
              ),
            ),
            Container(
              height: 5.0,
            ),
            Container(
              padding: EdgeInsets.all(
                5.0
              ),
              decoration: BoxDecoration(
                border: Border.all(
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(
                    5.0
                  )
                )
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    "Image",
                    style: TextStyle(
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Container(
                    height: 5.0,
                  ),
                  Image.network(
                    "https://firebasestorage.googleapis.com/v0/b/fire-notifier-17111.appspot.com/o/lastalert.jpg?alt=media"
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
