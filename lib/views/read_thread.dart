import 'package:flutter/material.dart';

import '../bdwm/vote.dart';
import './utils.dart';
import './constants.dart';
import '../html_parser/read_thread_parser.dart';
import '../pages/detail_image.dart';

class OnePostComponent extends StatefulWidget {
  OnePostInfo onePostInfo = OnePostInfo.empty();
  String bid = "";
  OnePostComponent({Key? key, required this.onePostInfo, required this.bid}) : super(key: key);

  @override
  State<OnePostComponent> createState() => _OnePostComponentState();
}

class _OnePostComponentState extends State<OnePostComponent> {
  final _contentFont = const TextStyle(fontSize: 16, fontWeight: FontWeight.normal);
  bool iVoteUp = false;
  bool iVoteDown = false;
  int voteUpCount = 0;
  int voteDownCount = 0;
  bool get simpleAttachment => false;

  @override
  void initState() {
    super.initState();
    iVoteUp = widget.onePostInfo.iVoteUp;
    iVoteDown = widget.onePostInfo.iVoteDown;
    voteUpCount = widget.onePostInfo.upCount;
    voteDownCount = widget.onePostInfo.downCount;
  }

  Widget renderAttachment() {
    var attachments = widget.onePostInfo.attachmentInfo;
    const spaceSpacer = Text(" ");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachments.map((e) {
        if (e.type == AttachmentType.showText) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.attachment),
              spaceSpacer,
              Flexible(
                child: GestureDetector(
                  child: Text.rich(
                    TextSpan(
                      text: e.text,
                      style: textLinkStyle,
                      children: [
                        TextSpan(
                          text: e.size,
                          style: textLinkSiblingStyle,
                        ),
                      ]
                    ),
                  ),
                  onTap: () {
                    gotoDetailImage(context: context, link: e.link, name: e.text);
                  },
                ),
              ),
            ],
          );
        } else if (e.type == AttachmentType.showThumbnail) {
          return GestureDetector(
            child: Image.network(
              e.thumbnailLink,
              errorBuilder: (context, error, stackTrace) {
                return Text("${e.text} 加载失败");
              },
            ),
            onTap: () {
              gotoDetailImage(context: context, link: e.link, name: e.text);
            },
          );
        }
        return Text("42");
      },).toList(),
    );
  }

  void vote(String action) async {
    if (action == "up" && iVoteUp == true) {
      action = "clear";
    }
    if (action == "down" && iVoteDown == true) {
      action = "clear";
    }
    bdwmVote(widget.bid, widget.onePostInfo.postID, action).then((value) {
      if (value.success) {
        setState(() {
          if (action == "clear") {
            iVoteUp = false;
            iVoteDown = false;
          } else if (action == "up") {
            iVoteUp = true;
            iVoteDown = false;
          } else if (action == "down") {
            iVoteUp = false;
            iVoteDown = true;
          }
          voteUpCount = value.upCount;
          voteDownCount = value.downCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ok"),
          ),
        );
      } else {
        var text = "";
        switch (value.error) {
          case 9:
            text = "抱歉，您没有本版回复(点赞)权限";
            break;
          case 11:
          default:
            text = "暂时无法这么操作";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
          ),
        );
      }
    },);
  }

  Widget _toolBox(OnePostInfo item) {
    const borderColor = Colors.blueGrey;
    const voteSize = 12.0;
    const widthSpacer = SizedBox(width: 5,);
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(voteSize/2)),
              // border: Border.all(width: 1, color: Colors.red),
              border: Border.all(color: borderColor, width: 1.0, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                widthSpacer,
                GestureDetector(
                  child: Icon(
                    iVoteUp ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: voteSize, color: Color(0xff5cae97),
                  ),
                  onTap: () {
                    vote("up");
                  },
                ),
                widthSpacer,
                const Text("赞 ", style: TextStyle(fontSize: voteSize)),
                Text(voteUpCount.toString()),
                const VerticalDivider(
                  color: borderColor,
                  width: 10.0,
                  thickness: 1.0,
                ),
                GestureDetector(
                  child: Icon(
                    iVoteDown ? Icons.thumb_down : Icons.thumb_down_outlined,
                    size: voteSize, color: Color(0xffe97c62),
                  ),
                  onTap: () {
                    vote("down");
                  },
                ),
                widthSpacer,
                const Text("踩 ", style: TextStyle(fontSize: voteSize)),
                Text(voteDownCount.toString()),
                widthSpacer,
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.onePostInfo;
    double deviceWidth = MediaQuery.of(context).size.width;
    return Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52.0,
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                GestureDetector(
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    backgroundImage: NetworkImage(item.authorInfo.avatarLink),
                  ),
                  onTap: () {
                    if (item.authorInfo.uid.isEmpty) {
                      return;
                    }
                    Navigator.of(context).pushNamed('/user', arguments: item.authorInfo.uid);
                  },
                ),
                if (item.postOwner)
                  const Text("楼主", style: TextStyle(fontSize: 12, color: Colors.lightBlue)),
                Text(item.postNumber, style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 10.0, right: 10.0, bottom: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.authorInfo.userName),
                      Text(' ('),
                      Flexible(child: renderHtml(item.authorInfo.nickName, needSelect: false),),
                      Text(')'),
                      Text(item.authorInfo.status),
                    ],
                  ),
                  if (item.modifyTime.isNotEmpty)
                    Text(
                      item.modifyTime,
                    ),
                  Text(
                    item.postTime,
                  ),
                  Divider(),
                  renderHtml(item.content, ts: _contentFont),
                  _toolBox(item),
                  if (item.signature.isNotEmpty)
                    ...[
                      Divider(),
                      renderHtml(item.signature),
                    ],
                  if (item.attachmentInfo.isNotEmpty)
                    ...[
                      Divider(),
                      const Text("附件", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                    if (simpleAttachment)
                      ...[
                        renderHtml(item.attachmentHtml, context: context),
                      ]
                    else
                      renderAttachment(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReadThreadPage extends StatefulWidget {
  final String bid;
  final String threadid;
  final String page;
  final ThreadPageInfo threadPageInfo;
  ReadThreadPage({Key? key, required this.bid, required this.threadid, required this.page, required this.threadPageInfo}) : super(key: key);

  @override
  State<ReadThreadPage> createState() => _ReadThreadPageState();
}

class _ReadThreadPageState extends State<ReadThreadPage> {
  final _titleFont = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  @override
  void initState() {
    super.initState();
    // getData().then((value) {
    //   setState(() {
    //     threadPageInfo = value;
    //   });
    // });
  }

  Widget _onepost(OnePostInfo item) {
    return OnePostComponent(onePostInfo: item, bid: widget.bid);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: ScrollController(),
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          widget.threadPageInfo.title,
          style: _titleFont,
        ),
        ...widget.threadPageInfo.posts.map((OnePostInfo item) {
          return _onepost(item);
        }).toList(),
      ],
    );
  }
}
