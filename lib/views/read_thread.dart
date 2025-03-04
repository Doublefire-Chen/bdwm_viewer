import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:extended_image/extended_image.dart';

import '../bdwm/vote.dart';
import '../bdwm/posts.dart';
import '../bdwm/collection.dart';
import '../bdwm/forward.dart';
import './collection.dart';
import './utils.dart';
import './constants.dart';
import '../html_parser/read_thread_parser.dart';
import '../globalvars.dart' show globalConfigInfo;
import '../pages/detail_image.dart';
import './html_widget.dart';
import '../router.dart' show nv2Push;

class OperateComponent extends StatefulWidget {
  final String bid;
  final String? boardName;
  final String threadid;
  final String postid;
  final String uid;
  final Function refreshCallBack;
  final OnePostInfo onePostInfo;
  const OperateComponent({
    super.key,
    required this.bid, required this.threadid, required this.postid, required this.uid,
    required this.refreshCallBack, this.boardName, required this.onePostInfo,
  });

  @override
  State<OperateComponent> createState() => _OperateComponentState();
}

class _OperateComponentState extends State<OperateComponent> {
  var canReplyNotifier = ValueNotifier<bool>(false);
  final textButtonStyle = TextButton.styleFrom(
    minimumSize: const Size(50, 20),
    padding: const EdgeInsets.all(6.0),
    // textStyle: MaterialStatePropertyAll(TextStyle(fontSize: 12)),
  );
  Widget sizedTextButton({required Widget child, required void Function()? onPressed, ButtonStyle? style}) {
    return SizedBox(
      height: 30,
      child: TextButton(
        style: style,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    canReplyNotifier.value = widget.onePostInfo.canReply;
  }
  @override
  void dispose() {
    canReplyNotifier.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Wrap(
      // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      // alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ValueListenableBuilder(
          valueListenable: canReplyNotifier,
          builder: (context, value, child) {
            var canReply = value as bool;
            return sizedTextButton(
              style: textButtonStyle,
              onPressed: !canReply ? null
                : () {
                  nv2Push(context, '/post', arguments: {
                    'bid': widget.bid,
                    'boardName': "回帖",
                    'parentid': widget.postid,
                    // Anonymous's nickname
                    'nickName': widget.onePostInfo.authorInfo.userName == "Anonymous"
                      ? widget.onePostInfo.authorInfo.nickName : null,
                  });
                },
              child: Text("回帖", style: TextStyle(color: !canReply ? Colors.grey : null),),
            );
          },
        ),
        sizedTextButton(
          style: textButtonStyle,
          onPressed: () {
            showTextDialog(context, "转载到的版面")
            .then((value) {
              if (value == null || value.isEmpty) {
                return;
              }
              bdwmForwrad("post", "post", widget.bid, widget.postid, value)
              .then((res) {
                var title = "转载";
                var content = "成功";
                if (!res.success) {
                  if (res.error == -1) {
                    content = res.desc!;
                  } else {
                    content = "该版面不存在，或需要特殊权限";
                  }
                }
                showAlertDialog(context, title, Text(content),
                  actions1: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("知道了"),
                  ),
                );
              });
            },);
          },
          child: const Text("转载"),
        ),
        sizedTextButton(
          style: textButtonStyle,
          onPressed: () {
            showTextDialog(context, "转寄给")
            .then((value) {
              if (value == null || value.isEmpty) {
                return;
              }
              bdwmForwrad("post", "mail", widget.bid, widget.postid, value)
              .then((res) {
                var title = "转寄";
                var content = "成功";
                if (!res.success) {
                  if (res.error == -1) {
                    content = res.desc!;
                  } else {
                    content = "用户不存在";
                  }
                }
                showAlertDialog(context, title, Text(content),
                  actions1: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("知道了"),
                  ),
                );
              });
            },);
          },
          child: const Text("转寄"),
        ),
        // if (globalUInfo.uid == widget.uid && globalUInfo.login == true)
        if (widget.onePostInfo.canModify)
          sizedTextButton(
            style: textButtonStyle,
            onPressed: () {
              nv2Push(context, '/post', arguments: {
                'bid': widget.bid,
                'boardName': "修改",
                'postid': widget.postid,
              });
            },
            child: const Text("修改"),
          ),
        // if (globalUInfo.uid == widget.uid && globalUInfo.login == true)
        // const Spacer(),
        PopupMenuButton<String>(
          child: SizedBox(
            width: 36,
            height: 30,
            child: Icon(Icons.more_horiz, color: bdwmPrimaryColor,),
          ),
          onSelected: (value) {
            if (value.contains("回复")) {
              var action = "unnoreply";
              if (canReplyNotifier.value) {
                action = "noreply";
              }
              bdwmOperatePost(bid: widget.bid, postid: widget.postid, action: action)
              .then((res) {
                var txt = "操作成功";
                if (!res.success) {
                  txt = "操作失败";
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(txt),
                    duration: const Duration(milliseconds: 1000),
                  ),
                );
                if (!res.success) { return; }
                // setState(() {
                canReplyNotifier.value = !canReplyNotifier.value;
                // });
              });
            } else if (value == "收入文集") {
              showCollectionDialog(context)
              .then((value) {
                if (value == null || value.isEmpty) {
                  return;
                }
                var values = value.split(" ");
                var mode = values[0];
                var base = values[1];
                if (base.isEmpty || base=="none") {
                  return;
                }
                bdwmCollectionImport(from: "post", bid: widget.bid, postid: widget.postid, threadid: widget.threadid, base: base, mode: mode)
                .then((importRes) {
                  var txt = "收藏成功";
                  if (importRes.success == false) {
                    txt = "发生错误啦><";
                    if (importRes.error == -1) {
                      txt = importRes.desc ?? txt;
                    } else if (importRes.error == 9) {
                      txt = "您没有足够权限执行此操作";
                    }
                  }
                  showAlertDialog(context, "收入文集", Text(txt),
                    actions1: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("知道了"),
                    ),
                  );
                });
              });
            } else if (value == "删除") {
              showConfirmDialog(context, "删除帖子", "确认删除？").then((value) {
                if (value==null) { return; }
                if (value.isEmpty) { return; }
                if (value != "yes") { return; }
                bdwmDeletePost(bid: widget.bid, postid: widget.postid).then((value) {
                  var title = "删除";
                  var content = "删除成功";
                  if (!value.success) {
                    content = "删除失败";
                    if (value.error == -1) {
                      content = value.result!;
                    }
                  }
                  showInformDialog(context, title, content).then((value2) {
                    if (value.success) {
                      widget.refreshCallBack();
                    }
                  });
                });
              });
            } else if (value == "回站内信") {
              nv2Push(context, "/mailNew", arguments: {
                'bid': widget.bid,
                'parentid': widget.postid,
                'receiver': widget.onePostInfo.authorInfo.userName,
              });
            }
          },
          itemBuilder: (context) {
            return <PopupMenuEntry<String>>[
              if (widget.onePostInfo.canSetReply)
                PopupMenuItem(
                  value: canReplyNotifier.value ? "设为不可回复" : "取消不可回复",
                  child: Text(canReplyNotifier.value ? "设为不可回复" : "取消不可回复"),
                ),
              if (widget.onePostInfo.canDelete)
                const PopupMenuItem(
                  value: "删除",
                  child: Text("删除"),
                ),
              const PopupMenuItem(
                value: "收入文集",
                child: Text("收入文集"),
              ),
              PopupMenuItem(
                value: "回站内信",
                enabled: widget.onePostInfo.authorInfo.userName != "Anonymous",
                child: const Text("回站内信"),
              ),
            ];
          },
        )
      ],
    );
  }
}

class VoteComponent extends StatefulWidget {
  final String bid;
  final String postID;
  final bool iVoteUp;
  final bool iVoteDown;
  final int voteUpCount;
  final int voteDownCount;
  final void Function(bool isVoteUp, int voteUpCount, bool isVoteDown, int voteDownCount)? callBack;
  const VoteComponent({
    Key? key,
    required this.iVoteUp,
    required this.iVoteDown,
    required this.voteUpCount,
    required this.voteDownCount,
    required this.bid,
    required this.postID,
    this.callBack,
  }) : super(key: key);

  @override
  State<VoteComponent> createState() => _VoteComponentState();
}

class _VoteComponentState extends State<VoteComponent> {
  bool iVoteUp = false;
  bool iVoteDown = false;
  int voteUpCount = 0;
  int voteDownCount = 0;

  static const voteSize = 16.0;
  static const borderColor = Colors.grey;
  static const widthSpacer = SizedBox(width: 5,);

  @override
  void initState() {
    super.initState();
    iVoteUp = widget.iVoteUp;
    iVoteDown = widget.iVoteDown;
    voteUpCount = widget.voteUpCount;
    voteDownCount = widget.voteDownCount;
  }

  void vote(String action) async {
    if (action == "up" && iVoteUp == true) {
      action = "clear";
    }
    if (action == "down" && iVoteDown == true) {
      action = "clear";
    }
    bdwmVote(widget.bid, widget.postID, action).then((value) {
      if (value.success) {
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
        if (widget.callBack != null) {
          widget.callBack!(iVoteUp, voteUpCount, iVoteDown, voteDownCount);
        }
        setState(() { });
      } else {
        var text = "";
        switch (value.error) {
          case -1:
            text = value.desc ?? "";
            break;
          case 9:
          case 16:
            text = "抱歉，您没有本版回复(点赞)权限";
            break;
          case 11:
            text = "暂时无法这么操作";
            break;
          default:
            text = "操作失败";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    },);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      // padding: const EdgeInsets.only(top: 10),
      height: 26,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(voteSize/2)),
        // border: Border.all(width: 1, color: Colors.red),
        border: Border.all(color: borderColor, width: 1.0, style: BorderStyle.solid),
      ),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.end,
        // mainAxisSize: MainAxisSize.max,
        children: [
          widthSpacer,
          GestureDetector(
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    child: Icon(
                      iVoteUp ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: voteSize, color: const Color(0xff5cae97),
                    ),
                    alignment: PlaceholderAlignment.middle,
                  ),
                  const TextSpan(text: " "),
                  TextSpan(text: voteUpCount.toString()),
                ]
              ),
            ),
            onTap: () {
              vote("up");
            },
          ),
          // const Text("赞 ", style: TextStyle(fontSize: voteSize)),
          const VerticalDivider(
            color: borderColor,
            width: 10.0,
            thickness: 1.0,
          ),
          GestureDetector(
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    child: Icon(
                      iVoteDown ? Icons.thumb_down : Icons.thumb_down_outlined,
                      size: voteSize, color: const Color(0xffe97c62),
                    ),
                    alignment: PlaceholderAlignment.middle,
                  ),
                  const TextSpan(text: " "),
                  TextSpan(text: voteDownCount.toString()),
                ]
              ),
            ),
            onTap: () {
              vote("down");
            },
          ),
          // const Text("踩 ", style: TextStyle(fontSize: voteSize)),
          widthSpacer,
        ],
      ),
    );
  }
}

class AttachmentComponent extends StatelessWidget {
  final List<AttachmentInfo> attachments;
  const AttachmentComponent({Key? key, required this.attachments}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                      children: [
                        TextSpan(
                          text: e.text,
                          style: textLinkStyle,
                        ),
                        TextSpan(
                          text: e.size,
                        ),
                      ]
                    ),
                  ),
                  onLongPress: () {
                    showLinkMenu(context, e.link, filename: e.text);
                  },
                  // onSecondaryTap: () {
                  //   showLinkMenu(context, e.link);
                  // },
                  onTap: () {
                    var parsedUrl = Uri.parse(e.link);
                    launchUrl(parsedUrl, mode: LaunchMode.externalApplication).then((result) {
                      if (result == true) { return; }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("打开链接失败"), duration: Duration(milliseconds: 600),),
                      );
                    });
                    // gotoDetailImage(context: context, link: e.link, name: e.text);
                  },
                ),
              ),
            ],
          );
        } else if (e.type == AttachmentType.showThumbnail) {
          return GestureDetector(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: Image.network(
                e.thumbnailLink,
                errorBuilder: (context, error, stackTrace) {
                  return Text("${e.text} 加载失败");
                },
              ),
            ),
            onTap: () {
              // gotoDetailImage(context: context, link: e.link, name: e.text);
              var imgLinks = <String>[], imgNames = <String>[];
              int curIdx = 0;
              int tmpIdx = 0;
              for (var element in attachments) {
                if (element.type == AttachmentType.showThumbnail) {
                  imgLinks.add(element.link);
                  imgNames.add(element.text);
                  if (element.link == e.link) {
                    curIdx = tmpIdx;
                  }
                  tmpIdx += 1;
                }
              }
              gotoDetailImage(context: context, link: "",
                imgLinks: imgLinks,
                imgNames: imgNames,
                curIdx: curIdx,
              );
            },
          );
        }
        return const Text("42");
      },).toList(),
    );
  }
}

class OnePostComponent extends StatefulWidget {
  final OnePostInfo onePostInfo;
  final String bid;
  final String threadid;
  final String? boardName;
  final Function refreshCallBack;
  final int? subIdx;
  final bool? hideIt;

  const OnePostComponent({Key? key, required this.onePostInfo, required this.bid, required this.refreshCallBack,
    this.boardName, required this.threadid, this.subIdx, this.hideIt}) : super(key: key);

  @override
  State<OnePostComponent> createState() => _OnePostComponentState();
}

class _OnePostComponentState extends State<OnePostComponent> {
  bool get simpleAttachment => false;
  final _contentFont = TextStyle(fontSize: globalConfigInfo.contentFontSize, fontWeight: FontWeight.normal);
  late bool hideIt;
  @override
  void initState() {
    super.initState();
    hideIt = widget.hideIt ?? false;
  }

  @override
  void didUpdateWidget(covariant OnePostComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    hideIt = widget.hideIt ?? false;
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.onePostInfo;
    // double deviceWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: widget.subIdx == null ? null : EdgeInsets.only(left: 20.0*widget.subIdx!),
      child: Card(
        // color: item.postNumber.contains("高亮") ? hightlightColor : null,
        child: hideIt
        ? Container(
          alignment: Alignment.center,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                hideIt = false;
              });
            },
            child: Text("${item.postNumber}：该帖子被`不看ta'折叠，点击展开"),
          ),
        )
        : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62.0,
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  GestureDetector(
                    child: CircleAvatar(
                      // radius: 20,
                      backgroundColor: Colors.white,
                      backgroundImage: NetworkImage(item.authorInfo.avatarLink),
                    ),
                    onTap: () {
                      if (item.authorInfo.uid.isEmpty) {
                        return;
                      }
                      nv2Push(context, '/user', arguments: item.authorInfo.uid);
                    },
                  ),
                  if (item.postOwner)
                    Text("楼主", style: TextStyle(fontSize: 12, color: bdwmPrimaryColor)),
                  Text(item.postNumber, style: TextStyle(fontSize: 12, color: item.postNumber.contains("高亮") ? highlightReplyColor : Colors.grey)),
                  if (item.isBaoLiu) genThreadLabel("保留"),
                  if (item.isWenZhai) genThreadLabel("文摘"),
                  if (item.isYuanChuang) genThreadLabel("原创"),
                  if (item.isJingHua) genThreadLabel("精华"),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(top: 10.0, right: 10.0, bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText.rich(
                      TextSpan(
                        style: const TextStyle(height: 1.0),
                        children: [
                          TextSpan(text: item.authorInfo.userName, style: serifFont),
                          const TextSpan(text: ' ('),
                          // WidgetSpan(child: HtmlComponent(item.authorInfo.nickName, needSelect: true),),
                          item.authorInfo.vipIdentity == -1
                          ? html2TextSpan(item.authorInfo.nickName)
                          : TextSpan(text: item.authorInfo.nickName, style: TextStyle(
                            color: getVipColor(item.authorInfo.vipIdentity, defaultColor: null),
                          )),
                          const TextSpan(text: ') '),
                          if (item.authorInfo.vipIdentity != -1) ...[
                            WidgetSpan(child: genVipLabel(item.authorInfo.vipIdentity)),
                          ],
                          TextSpan(
                            text: item.authorInfo.status,
                            style: TextStyle(color: item.authorInfo.status.contains("在线") ? onlineColor : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (item.modifyTime.isNotEmpty)
                      Text(
                        item.modifyTime,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      item.postTime,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(),
                    HtmlComponent(item.content, ts: _contentFont),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        VoteComponent(
                          iVoteUp: widget.onePostInfo.iVoteUp,
                          iVoteDown: widget.onePostInfo.iVoteDown,
                          voteUpCount: widget.onePostInfo.upCount,
                          voteDownCount: widget.onePostInfo.downCount,
                          bid: widget.bid,
                          postID: widget.onePostInfo.postID,
                          callBack: (isVoteUp, voteUpCount, isVoteDown, voteDownCount) {
                            widget.onePostInfo.iVoteUp = isVoteUp;
                            widget.onePostInfo.upCount = voteUpCount;
                            widget.onePostInfo.iVoteDown = isVoteDown;
                            widget.onePostInfo.downCount = voteDownCount;
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    OperateComponent(bid: widget.bid, threadid: widget.threadid, postid: widget.onePostInfo.postID,
                      uid: widget.onePostInfo.authorInfo.uid, refreshCallBack: widget.refreshCallBack,
                      boardName: widget.boardName, onePostInfo: widget.onePostInfo,
                    ),
                    if (item.attachmentInfo.isNotEmpty) ...[
                      const Divider(),
                      const Text("附件", style: TextStyle(fontWeight: FontWeight.bold)),
                      simpleAttachment
                      ? HtmlComponent(item.attachmentHtml)
                      : AttachmentComponent(attachments: widget.onePostInfo.attachmentInfo),
                    ],
                    if (item.signature.isNotEmpty) ...[
                      const Divider(),
                      HtmlComponent(item.signature),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TiebaFormItemInfo {
  int postid = 0;
  int oriIdx = 0;
  int parentIdx = 0; // for new order
  int subIdx = 0; // for indent
  TiebaFormItemInfo({
    required this.postid,
    required this.oriIdx,
    required this.parentIdx,
    required this.subIdx,
  });
  TiebaFormItemInfo copy() {
    return TiebaFormItemInfo(postid: postid, oriIdx: oriIdx, parentIdx: parentIdx, subIdx: subIdx);
  }
}
