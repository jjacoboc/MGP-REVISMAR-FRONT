import 'sharedPreferencesHelper.dart';
import 'constants.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_plugin_pdf_viewer/flutter_plugin_pdf_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayer/audioplayer.dart';

typedef void OnError(Exception exception);

enum PlayerState { stopped, playing, paused }

class PdfViewer extends StatefulWidget {
  @override
  _PdfViewerState createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {

  bool _isLoading = true;
  File document;
  PDFDocument pdfDocument;
  int _pageNumber = 1;
  int _oldPage = 0;
  PDFPage _page;
  String titleDocument;

  //audio player variables
  int hasAudio = 0;
  bool _isAudioLoading = true;
  String year = '';
  String edition = '';
  String article = '';
  String author = '';
  Duration duration;
  Duration position;

  AudioPlayer audioPlayer;

  String localFilePath;

  PlayerState playerState = PlayerState.stopped;

  get isPlaying => playerState == PlayerState.playing;

  get isPaused => playerState == PlayerState.paused;

  get durationText =>
      duration != null ? duration
          .toString()
          .split('.')
          .first : '';

  get positionText =>
      position != null ? position
          .toString()
          .split('.')
          .first : '';

  bool isMuted = false;

  StreamSubscription _positionSubscription;
  StreamSubscription _audioPlayerStateSubscription;

  @override
  void initState() {
    super.initState();
    Preference.load();
    this.hasAudio = Preference.getInt('hasAudio');
    this.downloadFile();
    if(this.hasAudio == 1) {
      this._loadAudioFile();
      this.initAudioPlayer();
    }
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _audioPlayerStateSubscription.cancel();
    audioPlayer.stop();
    super.dispose();
  }

  void initAudioPlayer() {
    audioPlayer = new AudioPlayer();
    _positionSubscription = audioPlayer.onAudioPositionChanged.listen((p) => setState(() => position = p));
    _audioPlayerStateSubscription = audioPlayer.onPlayerStateChanged.listen((s) {
          if (s == AudioPlayerState.PLAYING) {
            setState(() => duration = audioPlayer.duration);
          } else if (s == AudioPlayerState.STOPPED) {
            onComplete();
            setState(() {
              position = duration;
            });
          }
        }, onError: (msg) {
          setState(() {
            playerState = PlayerState.stopped;
            duration = new Duration(seconds: 0);
            position = new Duration(seconds: 0);
          });
        });
  }

  Future _playLocal() async {
    await audioPlayer.play(localFilePath, isLocal: true);
    setState(() => playerState = PlayerState.playing);
  }

  Future pause() async {
    await audioPlayer.pause();
    setState(() => playerState = PlayerState.paused);
  }

  Future stop() async {
    await audioPlayer.stop();
    setState(() {
      playerState = PlayerState.stopped;
      position = new Duration();
    });
  }

  Future mute(bool muted) async {
    await audioPlayer.mute(muted);
    setState(() {
      isMuted = muted;
    });
  }

  void onComplete() {
    setState(() => playerState = PlayerState.stopped);
  }

  Future _loadAudioFile() async {
    Preference.load();
    String strYear = Preference.getString('year');
    String strEdition = Preference.getString('edition');
    String strArticle = Preference.getString('article');
    String strAuthor = Preference.getString('author');
    String i = Preference.getString("indexSection");
    String j = Preference.getString("indexArticle");
    String filename = "audio" + i + j;

    String url = Constants.url_bucket + strYear + Constants.separator + strEdition + Constants.separator + filename + Constants.mp3_ext;
    final bytes = await _loadFileBytes(url, onError: (Exception exception) => print('_loadFile => exception $exception'));
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = new File('$dir/$filename.' + Constants.mp3);

    await file.writeAsBytes(bytes);
    if (await file.exists()) {
      setState(() {
        localFilePath = file.path;
        year = strYear;
        edition = strEdition;
        article = strArticle;
        author = strAuthor;
        _isAudioLoading = false;
      });
    }
  }

  Future<Uint8List> _loadFileBytes(String url, {OnError onError}) async {
    Uint8List bytes;
    try {
      bytes = await http.readBytes(url);
    } on http.ClientException {
      rethrow;
    }
    return bytes;
  }

  downloadFile() async {
    Preference.load();
    String year = Preference.getString("year");
    String edition = Preference.getString("edition");
    String title = Preference.getString("title");
    String i = Preference.getString("indexSection");
    String j = Preference.getString("indexArticle");
    String filename = "articulo" + i + j;

    var response = await http.get(
        Uri.encodeFull(Constants.url_document + year + Constants.separator + edition + Constants.separator + filename + Constants.separator + Constants.pdf));
        //Uri.encodeFull("http://10.0.2.2:8084/document/1907/04/AparatoDelCapitanScott.pdf"));

    var bytes = response.bodyBytes;
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = new File('$dir/$filename.' + Constants.pdf);
    this.document = await file.writeAsBytes(bytes);
    setState(() {
      this.document = file;
      this.titleDocument = title;
    });
    this.loadDocument();
  }

  loadDocument() async {
    pdfDocument = await PDFDocument.fromFile(this.document);
    _loadPage();
    setState(() => _isLoading = false);
  }

  _loadPage() async {
    setState(() {
      _isLoading = true;
    });
    if (_oldPage == 0) {
      _page = await pdfDocument.get(page: _pageNumber);
      setState(() => _isLoading = false);
    } else if (_oldPage != _pageNumber) {
      _oldPage = _pageNumber;
      setState(() => _isLoading = true);
      _page = await pdfDocument.get(page: _pageNumber);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(
            title: this.titleDocument != null ? Text(this.titleDocument) : Text(""),
            backgroundColor: Color.fromRGBO(2, 29, 38, 0.8),
            leading: IconButton(icon:Icon(Icons.arrow_back),
              onPressed:() => Navigator.pop(context, false),
            ),
          ),
          resizeToAvoidBottomInset: false,
          resizeToAvoidBottomPadding: false,
          body: Center(
              child: _isLoading
                  ? Center(
                  child: new Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        valueColor: new AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      Container(
                        padding: EdgeInsets.only(top: 10.0),
                        child: Text('cargando artículo...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman')),
                      )
                    ],
                  )
              ) : _page,
              ),
            bottomNavigationBar: _buildBottomAppBar(),
          ),
        );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          this.hasAudio == 1 ?
          (duration == null ?
            Container()
                : Slider(
              value: position?.inMilliseconds?.toDouble() ?? 0.0,
              onChanged: (double value) =>
                  audioPlayer.seek((value / 1000).roundToDouble()),
              min: 0.0,
              max: duration.inMilliseconds.toDouble(),
              activeColor: Color.fromRGBO(2, 29, 38, 0.9),
              inactiveColor: Colors.grey,
            )
          ) : Container(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: IconButton(
                  icon: Icon(Icons.first_page),
                  onPressed: () {
                    _pageNumber = 1;
                    _loadPage();
                  },
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: () {
                    _pageNumber--;
                    if (1 > _pageNumber) {
                      _pageNumber = 1;
                    }
                    _loadPage();
                  },
                ),
              ),
              this.hasAudio == 1 ?
              (_isAudioLoading ?
              Expanded(
                  child: IconButton(
                    iconSize: 64.0,
                    icon: new Icon(Icons.play_arrow),
                    color: Colors.grey,
                    onPressed: null,
                  )
              ) :
              isPlaying ?
              Expanded(
                  child: IconButton(
                      onPressed: () => pause(),
                      iconSize: 64.0,
                      icon: new Icon(Icons.pause),
                      color: Colors.amber
                  )
              ) :
              Expanded(
                  child: IconButton(
                    onPressed: () => _playLocal(),
                    iconSize: 64.0,
                    icon: new Icon(Icons.play_arrow),
                    color: Colors.green,
                  )
              )
              ) : Container(),
              Expanded(
                child: IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: () {
                    _pageNumber++;
                    if (pdfDocument.count < _pageNumber) {
                      _pageNumber = pdfDocument.count;
                    }
                    _loadPage();
                  },
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(Icons.last_page),
                  //tooltip: widget.tooltip.last,
                  onPressed: () {
                    _pageNumber = pdfDocument.count;
                    _loadPage();
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}