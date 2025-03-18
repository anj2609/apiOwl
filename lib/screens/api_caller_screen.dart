import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import '../service.dart' as servicess;
import 'package:loader_overlay/loader_overlay.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:video_player/video_player.dart';
import 'package:upi_pay/upi_pay.dart';
import 'dart:math';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';

class ApiCallerScreen extends StatefulWidget {
  const ApiCallerScreen({super.key});

  @override
  _ApiCallerScreenState createState() => _ApiCallerScreenState();
}

class _ApiCallerScreenState extends State<ApiCallerScreen>
    with WidgetsBindingObserver {
  late TextEditingController _apiUrlController;
  late TextEditingController _intervalController;
  late SharedPreferences _prefs;
  bool _isRunning = false;
  late int _interval;
  bool textfield = true;
  late String _apiUrl;
  List<ApplicationMeta>? _apps;
  final _formKey = GlobalKey<FormState>();
  //upi plugins and tehhir variables
  final upiPay = UpiPay();
  bool _showapps = false;

  static const String _adTagUrl =
      "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=sample_ct%3Dlinear&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator=";
  late final AdsLoader _adsLoader;
  AdsManager? _adsManager;
  final AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  final bool _shouldShowAds = true;
  late final VideoPlayerController _contentVideoController;
  bool _shouldShowContentVideo = false;
  late final AdDisplayContainer _adDisplayContainer =
      AdDisplayContainer(onContainerAdded: (AdDisplayContainer container) {
    _adsLoader = AdsLoader(
      container: container,
      onAdsLoaded: (OnAdsLoadedData data) {
        final AdsManager manager = data.manager;
        _adsManager = data.manager;
        manager.setAdsManagerDelegate(
          AdsManagerDelegate(onAdEvent: (AdEvent event) {
            debugPrint('OnAdEvent : ${event.type} => ${event.adData}');
            switch (event.type) {
              case AdEventType.loaded:
                manager.start();
                break;
              case AdEventType.contentPauseRequested:
                _pauseContent();
                break;
              case AdEventType.contentResumeRequested:
                _resumeContent();
                break;
              case AdEventType.allAdsCompleted:
                _requestAds(container);

                break;
              case AdEventType.complete:
                _requestAds(container);
                break;
              case AdEventType.clicked:
                break;

              default:
                debugPrint('Unhandled AdEventType: ${event.type}');
                break;
            }
          }, onAdErrorEvent: (AdErrorEvent event) {
            debugPrint("ad error: ${event.error.message}");
            _resumeContent();
          }),
        );
        manager.init();
      },
      onAdsLoadError: (AdsLoadErrorData data) {
        debugPrint("ad error: ${data.error.message}");
        _resumeContent();
      },
    );
    _requestAds(container);
    // Moved outside the constructor
  });

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController();
    _intervalController = TextEditingController();
    _initializeSharedPreferences();
    Future.delayed(Duration(milliseconds: 0), () async {
      _apps = await upiPay.getInstalledUpiApplications(
          statusType: UpiApplicationDiscoveryAppStatusType.all);
      setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);

    _contentVideoController = VideoPlayerController.networkUrl(
      Uri.parse(
          "https://drive.google.com/uc?export=download&id=1pP3rCR9pr2g-tUmKhZAFOfqgD_Fg1n2c"),
    )
      ..addListener(() {
        if (_contentVideoController.value.isCompleted) {
          _adsLoader.contentComplete();
        }
        setState(() {});
      })
      ..initialize().then((_) {
        setState(() {});
      });
  }

  Widget appWidget(ApplicationMeta appMeta) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        appMeta.iconImage(48), // dev.logo
        Container(
          margin: EdgeInsets.only(top: 4),
          alignment: Alignment.center,
          child: Text(
            appMeta.upiApplication.getAppName(),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return Container(
      margin: EdgeInsets.only(top: 32),
      child: Row(
        children: <Widget>[
          Expanded(
            child: MaterialButton(
              onPressed: () async => await _onTap(_apps![0]),
              color: Theme.of(context).primaryColor,
              height: 48,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              child: Text('Buy me a coffee',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _androidApps() {
    return Container(
      margin: EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        // mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(bottom: 0),
            // child: Text(
            //   'Pay Using',
            //   style: Theme.of(context).textTheme.bodyMedium,
            // ),
          ),
          if (_apps != null) _appsGrid(_apps!.map((e) => e).toList()),
        ],
      ),
    );
  }

  Future<void> _onTap(ApplicationMeta app) async {
    final transactionRef = Random.secure().nextInt(1 << 32).toString();
    print("Starting transaction with id $transactionRef");

    final a = await upiPay.initiateTransaction(
      amount: '15.00',
      app: app.upiApplication,
      receiverName: 'Srayansh Gupta',
      receiverUpiAddress: 'sr.gupta621@oksbi',
      transactionRef: transactionRef,
      transactionNote: 'Buy me a coffee',
    );

    print(a);
  }

  GridView _appsGrid(List<ApplicationMeta> apps) {
    apps.sort((a, b) => a.upiApplication
        .getAppName()
        .toLowerCase()
        .compareTo(b.upiApplication.getAppName().toLowerCase()));
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      // childAspectRatio: 1.6,
      physics: NeverScrollableScrollPhysics(),
      children: apps
          .map(
            (it) => Material(
              key: ObjectKey(it.upiApplication),
              // color: Colors.grey[200],
              child: InkWell(
                onTap: Platform.isAndroid ? () async => await _onTap(it) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    it.iconImage(48),
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      alignment: Alignment.center,
                      child: Text(
                        it.upiApplication.getAppName(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          dev.log("App detached, cleaning up service");
          await _prefs.setBool('service_running', false);
          service.invoke("stopService");
          await Future.delayed(const Duration(seconds: 2));
          _adsManager?.start();
        }
        break;
      case AppLifecycleState.hidden:
        _pauseContent();
        break;
      case AppLifecycleState.inactive:
        _pauseContent();
        break;
      case AppLifecycleState.paused:
        _pauseContent();
        break;
      case AppLifecycleState.resumed:
        // Handle resumed state if needed
        if (!_shouldShowContentVideo) {
          _adsManager?.resume();
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiUrlController.dispose();
    _intervalController.dispose();
    _contentVideoController.dispose();
    _adsManager?.destroy();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final service = FlutterBackgroundService();

    await service.startService();
    setState(() {
      _apiUrlController.text = _prefs.getString('api_url') ?? '';
      _apiUrl = _prefs.getString('api_url') ?? '';
      _interval = _prefs.getInt('interval') ?? 0;
      _intervalController.text = _interval.toString();
      _isRunning = _prefs.getBool('service_running') ?? false;
    });
  }

  Future<void> _toggleService(BuildContext context) async {
    context.loaderOverlay.show();

    final service = FlutterBackgroundService();
    final isRunning = _prefs.getBool('service_running') ?? false;

    service.invoke("stopService");
    try {
      if (isRunning) {
        dev.log("Stopping Service...");
        await _prefs.setBool('service_running', false);
        service.invoke("stopService");

        int attempts = 0;
        while (await service.isRunning() && attempts < 5) {
          await Future.delayed(const Duration(seconds: 1));
          attempts++;
          dev.log("Waiting for service to stop - attempt $attempts");
        }

        setState(() => _isRunning = false);
        setState(() {
          textfield = true;
        });
        dev.log("Service stopped successfully");
      } else {
        dev.log("Starting Service...");

        if (_formKey.currentState?.validate() ?? false) {
          await _prefs.setString('api_url', _apiUrlController.text);
          await _prefs.setInt('interval', int.parse(_intervalController.text));
          await _prefs.setBool('service_running', true);
          var apiUrl = _prefs.getString('api_url') ?? '';

          await service.startService();
          servicess.makeApiCall(apiUrl);

          await Future.delayed(const Duration(seconds: 2));

          if (await service.isRunning()) {
            setState(() => _isRunning = true);
            setState(() {
              textfield = false;
            });
            dev.log("Service started successfully");
          } else {
            throw Exception("Failed to start service");
          }
        }
      }
    } catch (e) {
      dev.log("Service error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        context.loaderOverlay.hide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      home: GlobalLoaderOverlay(
        child: Scaffold(
          backgroundColor: const Color(0xFF2F3136),
          appBar: AppBar(
            title: const Text('APIOwl', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF292B2F),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            enabled: !_isRunning,
                            maxLength: 100,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9\-._~:/?#\[\]@!$&()*+,;=]')),
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                            keyboardType: TextInputType.url,
                            controller: _apiUrlController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              counterText: "",
                              labelText: 'API URL',
                              labelStyle: TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.blue, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'API URL cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            enabled: !_isRunning,
                            maxLength: 4,
                            controller: _intervalController,
                            style: const TextStyle(color: Colors.white),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              FilteringTextInputFormatter.deny(RegExp(r'\.')),
                            ],
                            decoration: const InputDecoration(
                              counterText: "",
                              labelText: 'Interval (minutes)',
                              labelStyle: TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.blue, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Interval cannot be empty';
                              }
                              int? intervalValue = int.tryParse(value.trim());
                              if (intervalValue == null || intervalValue <= 0) {
                                return 'Interval must be greater than zero';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: width * 0.9,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _toggleService(context),
                              child: Text(
                                _isRunning ? 'Stop API Calls' : 'Start API Calls',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 400,
                      child: !_contentVideoController.value.isInitialized
                          ? Container()
                          : AspectRatio(
                              aspectRatio:
                                  _contentVideoController.value.aspectRatio,
                              child: Stack(
                                children: <Widget>[
                                  _adDisplayContainer,
                                  if (_shouldShowContentVideo)
                                    VideoPlayer(_contentVideoController),
                                ],
                              ),
                            ),
                    ),
                    _showapps ? _androidApps() : Container(),
                    SizedBox(height: 5,),
                    !_showapps ? SizedBox(height: 20,) : Container(),
                    GestureDetector(
                      child: SvgPicture.asset("assets/icons/bmcoffee.svg",
                      height: 100,),
                      onTap: () {
                        setState(() {
                          _showapps = !_showapps;
                        });
                      },
                    ),
                    
                    // _submitButton(),
                    // GooglePayButton(paymentConfiguration: paymentConfiguration, paymentItems: paymentItems)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestAds(AdDisplayContainer container) {
    return _adsLoader.requestAds(AdsRequest(adTagUrl: _adTagUrl));
  }

  Future<void> _resumeContent() {
    setState(() {
      _shouldShowContentVideo = true;
    });
    return _contentVideoController.play();
  }

  Future<void> _pauseContent() {
    setState(() {
      _shouldShowContentVideo = false;
    });
    return _contentVideoController.pause();
  }
}
