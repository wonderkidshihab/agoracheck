import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/material.dart';
import 'package:shihab/utils/utils.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;

class AudiencePage extends StatefulWidget {
  final String channelName;
  final String userName;
  const AudiencePage(
      {Key? key, required this.channelName, required this.userName})
      : super(key: key);

  @override
  _AudiencePageState createState() => _AudiencePageState();
}

class _AudiencePageState extends State<AudiencePage> {
  late RtcEngine _rtcEngine;
  late AgoraRtmClient? _rtmClient;
  late AgoraRtmChannel? _rtmChannel;
  bool _isJoined = false;
  bool? connected;
  @override
  void initState() {
    connectToBroadCaster();
    sendRequestForPermission();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: Text('Audience updated'),
      ),
      body: Center(
        child: connected == null
            ? CircularProgressIndicator()
            : connected!
                ? audienceView(context)
                : Center(
                    child: Text('No Broadcaster Found'),
                  ),
      ),
    );
  }

  void sendRequestForPermission() async {
    try {
      _rtmClient = await AgoraRtmClient.createInstance(APP_ID);

      await _rtmClient?.login(null, widget.userName);

      _rtmChannel = await _rtmClient?.createChannel(widget.channelName);
      await _rtmChannel?.join();
      _rtcEngine = await RtcEngine.create(APP_ID);
      await _rtcEngine.enableVideo();
      await _rtcEngine.enableAudio();
      await _rtcEngine.setChannelProfile(ChannelProfile.LiveBroadcasting);
      await _rtcEngine.setClientRole(ClientRole.Audience);
      await _rtcEngine.joinChannel(null, widget.channelName, null, 5);
      _rtcEngine.enableDualStreamMode(true);
      _rtcEngine.enableLocalVideo(true);

      setState(() {
        connected = true;
      });
    } on Exception catch (e) {
      setState(() {
        connected = false;
      });
      print(e.toString());
    }
  }

  @override
  void dispose() {
    // clear users
    // destroy sdks
    _rtcEngine.leaveChannel();
    _rtcEngine.destroy();
    _rtmClient?.destroy();
    _rtmChannel?.leave();
    super.dispose();
  }

  void connectToBroadCaster() async {
    await _rtmChannel?.sendMessage(
        AgoraRtmMessage.fromText("PERMISSION_REQUEST-${widget.userName}"));
    await Future.delayed(Duration(seconds: 1));
    _rtmClient?.onMessageReceived = (AgoraRtmMessage message, String peerId) {
      if (message.text == "PERMISSION_GRANTED-${widget.userName}") {
        setState(() {
          _isJoined = true;
        });
        _rtcEngine.setClientRole(ClientRole.Broadcaster);
      } else if (message.text == "PERMISSION_DENIED-${widget.userName}") {
        setState(() {
          _isJoined = false;
          Future.delayed(Duration(seconds: 1), () {
            Navigator.pop(context);
          });
        });
      }
    };
  }

  Center audienceView(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    width: MediaQuery.of(context).size.width,
                    child: RtcRemoteView.SurfaceView(
                      channelId: widget.channelName,
                      uid: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Visibility(
                    visible: _isJoined,
                    child: Container(
                      child: RtcLocalView.SurfaceView(),
                      height: MediaQuery.of(context).size.height / 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          audienceToolBar(context),
        ],
      ),
    );
  }

  Align audienceToolBar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Visibility(
              visible: _isJoined,
              child: RawMaterialButton(
                // onPressed: () => {_onCallEnd(context)},
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 30.0,
                ),
                shape: CircleBorder(),
                elevation: 2.0,
                fillColor: Colors.redAccent,
                padding: const EdgeInsets.all(10.0),
              ),
            ),
            Visibility(
              visible: !_isJoined,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.green),
                  onPressed: () async {
                    connectToBroadCaster();
                  },
                  child: Text(
                    "Join",
                    style: TextStyle(fontSize: 20),
                  )),
            ),
            Visibility(
              child: RawMaterialButton(
                onPressed: () {
                  _rtcEngine.switchCamera();
                },
                child: Icon(
                  Icons.switch_camera_outlined,
                  color: Colors.white,
                  size: 30.0,
                ),
                shape: CircleBorder(),
                elevation: 2.0,
                fillColor: Colors.grey,
                padding: const EdgeInsets.all(10.0),
              ),
              visible: _isJoined,
            ),
          ],
        ),
      ),
    );
  }
}
