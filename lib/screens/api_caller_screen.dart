import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import '../service.dart' as servicess;
import 'package:loader_overlay/loader_overlay.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:video_player/video_player.dart';

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

  final _formKey = GlobalKey<FormState>();

  static const String _adTagUrl =
      "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/12431969999/external/single_ad_samples&ciu_szs=300x250&impl=s&gdfp_req=1&env=vp&output=vast&unviewed_position_start=1&cust_params=deployment%3Ddevsite%26sample_ct%3Dlinear&correlator=";
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
                manager.destroy();
                _adsManager = null;
                break;
              case AdEventType.complete:
                manager.destroy();
                break;
              case AdEventType.skipped:
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
    _requestAds(container); // Moved outside the constructor
  });

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController();
    _intervalController = TextEditingController();
    _initializeSharedPreferences();
    WidgetsBinding.instance.addObserver(this);

    _contentVideoController = VideoPlayerController.networkUrl(
      Uri.parse(
          "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          log("App detached, cleaning up service");
          await _prefs.setBool('service_running', false);
          service.invoke("stopService");
          await Future.delayed(const Duration(seconds: 2));
        }
        break;
      case AppLifecycleState.hidden:
        // Handle hidden state if needed
        break;
      case AppLifecycleState.inactive:
        // Handle inactive state if needed
        break;
      case AppLifecycleState.paused:
        // Handle paused state if needed
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
        log("Stopping Service...");
        await _prefs.setBool('service_running', false);
        service.invoke("stopService");

        int attempts = 0;
        while (await service.isRunning() && attempts < 5) {
          await Future.delayed(const Duration(seconds: 1));
          attempts++;
          log("Waiting for service to stop - attempt $attempts");
        }

        setState(() => _isRunning = false);
        setState(() {
          textfield = true;
        });
        log("Service stopped successfully");
      } else {
        log("Starting Service...");

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
            log("Service started successfully");
          } else {
            throw Exception("Failed to start service");
          }
        }
      }
    } catch (e) {
      log("Service error: $e");
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
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _shouldShowContentVideo ? _pauseContent : _resumeContent,
            child:
                Icon(_shouldShowContentVideo ? Icons.pause : Icons.play_arrow),
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
