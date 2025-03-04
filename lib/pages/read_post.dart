import 'package:flutter/material.dart';
import 'package:async/async.dart';

import '../html_parser/read_post_parser.dart';
import '../bdwm/req.dart';
import '../globalvars.dart';
import '../views/read_thread.dart' show OnePostComponent;
import './read_thread.dart' show naviGotoThreadByLink;

class SinglePostApp extends StatefulWidget {
  final String bid;
  final String postid;
  final String? boardName;
  const SinglePostApp({Key? key, required this.bid, this.boardName, required this.postid}) : super(key: key);
  // ThreadApp.empty({Key? key}) : super(key: key);

  @override
  // State<ThreadApp> createState() => _ThreadAppState();
  State<SinglePostApp> createState() => _SinglePostAppState();
}

class _SinglePostAppState extends State<SinglePostApp> {
  static const _titleFont = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
  late CancelableOperation getDataCancelable;

  @override
  void initState() {
    super.initState();
    getDataCancelable = CancelableOperation.fromFuture(getData(firstTime: true), onCancel: () {
      debugPrint("cancel it");
    },);
  }

  @override
  void dispose() {
    Future.microtask(() => getDataCancelable.cancel(),);
    super.dispose();
  }

  Future<SinglePostInfo> getData({bool firstTime=false}) async {
    var url = "$v2Host/post-read-single.php?bid=${widget.bid}&postid=${widget.postid}";
    var resp = await bdwmClient.get(url, headers: genHeaders2());
    if (resp == null) {
      return SinglePostInfo.error(errorMessage: networkErrorText);
    }
    return parseSinglePost(resp.body);
  }

  void refresh() {
    setState(() {
      getDataCancelable = CancelableOperation.fromFuture(getData(), onCancel: () {
        debugPrint("cancel it");
      },);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getDataCancelable.value,
      builder: (context, snapshot) {
        // debugPrint(snapshot.connectionState.toString());
        if (snapshot.connectionState != ConnectionState.done) {
          // return const Center(child: CircularProgressIndicator());
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.boardName ?? "看帖"),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.boardName ?? "看帖"),
            ),
            body: Center(child: Text("错误：${snapshot.error}"),),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.boardName ?? "看帖"),
            ),
            body: const Center(child: Text("错误：未获取数据"),),
          );
        }
        var singlePostInfo = snapshot.data as SinglePostInfo;
        if (singlePostInfo.errorMessage != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.boardName ?? ""),
            ),
            body: Center(
              child: Text(singlePostInfo.errorMessage!),
            ),
          );
        }
        var boardName = singlePostInfo.board.text.split('(').first;
        return Scaffold(
          appBar: AppBar(
            title: Text(boardName),
            actions: [
              IconButton(
                onPressed: () {
                  naviGotoThreadByLink(context, singlePostInfo.threadLink, widget.boardName ?? "", needToBoard: true, replaceIt: true);
                },
                icon: const Icon(Icons.width_full_outlined)
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                alignment: Alignment.centerLeft,
                // height: 20,
                child: Text(
                  singlePostInfo.title,
                  style: _titleFont,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: OnePostComponent(bid: widget.bid, onePostInfo: singlePostInfo.postInfo,
                    threadid: singlePostInfo.threadid, boardName: boardName,
                    refreshCallBack: () {
                      refresh();
                    },
                  ),
                ),
              )
            ],
          ),
        );
      }
    );
  }
}
