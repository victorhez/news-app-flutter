import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:news_app/components/shimmer_news_tile.dart';
import 'package:news_app/provider/theme_provider.dart';
import 'package:news_app/components/news_tile.dart';
import 'package:news_app/helper/news.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  final String category;
  HomeScreen({required this.category});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List articles = [];
  bool _loading = true;
  int page = 1;
  bool _showConnected = false;
  bool _articleExists = true;
  bool _retryBtnDisabled = false;

  Icon themeIcon = Icon(Icons.dark_mode);
  bool isLightTheme = false;

  Color baseColor = Colors.grey[300]!;
  Color highlightColor = Colors.grey[100]!;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((event) {
      checkConnectivity();
    });
    _loading = true;
    getNews();
    getTheme();
  }

  getTheme() async {
    final settings = await Hive.openBox('settings');
    setState(() {
      isLightTheme = settings.get('isLightTheme') ?? false;
      baseColor = isLightTheme ? Colors.grey[300]! : Color(0xff2c2c2c);
      highlightColor = isLightTheme ? Colors.grey[100]! : Color(0xff373737);
      themeIcon = isLightTheme ? Icon(Icons.dark_mode) : Icon(Icons.light_mode);
    });
  }

  checkConnectivity() async {
    var result = await Connectivity().checkConnectivity();
    showConnectivitySnackBar(result);
  }

  void showConnectivitySnackBar(ConnectivityResult result) {
    var isConnected = result != ConnectivityResult.none;
    if (!isConnected) {
      _showConnected = true;
      final snackBar = SnackBar(
          content: Text(
            "You are Offline",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    if (isConnected && _showConnected) {
      _showConnected = false;
      final snackBar = SnackBar(
          content: Text(
            "You are back Online",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      getNews();
    }
  }

  Future<dynamic> getNews() async {
    checkConnectivity();

    var data = await http.get(
      Uri.parse('https://heznews.org/wp-json/wp/v2/posts?per_page=100'),
    );
    return json.decode(data.body);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
        appBar: AppBar(
          systemOverlayStyle:
              SystemUiOverlayStyle(statusBarColor: Colors.transparent),
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          leading: IconButton(
            onPressed: () {
              // Navigator.push(
              //   context,
              //   Transition(
              //     child: CategoryScreen(),
              //     transitionEffect: TransitionEffect.LEFT_TO_RIGHT,
              //   ),
              // );
              Fluttertoast.showToast(msg: 'Coming soon');
            },
            icon: Icon(
              Icons.amp_stories_outlined,
              size: 30,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Hez',
                style: TextStyle(color: Color(0xff50A3A4)),
              ),
              Text(
                'News',
                style: TextStyle(color: Color(0xffFCAF38)),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await themeProvider.toggleThemeData();
                setState(() {
                  themeIcon = themeProvider.themeIcon();
                });
              },
              icon: themeIcon,
            ),
          ],
        ),
        body: FutureBuilder<dynamic>(
            future: getNews(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("No data available"),
                        TextButton(
                          child: Text('Retry Now!'),
                          onPressed: () {
                            getNews();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 10,
                    itemBuilder: (BuildContext context, int index) {
                      return ShimmerNewsTile();
                    },
                  ),
                );
              } else {
                return RefreshIndicator(
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    physics: ClampingScrollPhysics(),
                    itemCount: snapshot.data.length,
                    itemBuilder: (BuildContext context, int index) {
                      return NewsTile(
                        image: snapshot.data[index]['yoast_head_json']
                                    ['og_image'] !=
                                null
                            ? snapshot.data[index]['yoast_head_json']
                                    ['og_image'][0]['url']
                                .toString()
                            : 'https://www.google.com.ng/images/branding/googlelogo/2x/googlelogo_color_160x56dp.png',
                        title: snapshot.data[index]['yoast_head_json']['title']
                            .toString(),
                        content: snapshot.data[index]['yoast_head_json']
                                ['og_description']
                            .toString(),
                        date: snapshot.data[index]['date'],
                        views: '1',
                        fullArticle: snapshot.data[index]['link'].toString(),
                      );
                    },
                  ),
                  onRefresh: () => getNews(),
                );
              }
            }));
  }
}
