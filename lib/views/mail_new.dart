import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:async/async.dart';
import 'package:flutter_quill/flutter_quill.dart' as fquill;
import 'package:flutter_quill_extensions/embeds/builders.dart' show ImageEmbedBuilder;

import '../bdwm/search.dart';
import '../bdwm/mail.dart';
import '../bdwm/req.dart';
import './constants.dart';
import '../globalvars.dart';
import './html_widget.dart';
import './quill_utils.dart';
import '../html_parser/utils.dart' show SignatureItem;
import '../html_parser/mailnew_parser.dart';
import './utils.dart';
import './upload.dart';

class MailNewPage extends StatefulWidget {
  final String? parentid;
  final String? content;
  final String? quote;
  final MailNewInfo mailNewInfo;
  final String? title;
  final String? receivers;
  const MailNewPage({super.key, this.parentid, this.content, this.quote, required this.mailNewInfo, this.title, this.receivers});

  @override
  State<MailNewPage> createState() => _MailNewPageState();
}

class _MailNewPageState extends State<MailNewPage> {
  late final fquill.QuillController _controller;
  TextEditingController titleValue = TextEditingController();
  TextEditingController receiveValue = TextEditingController();
  List<String>? friends;
  SignatureItem? signature;
  int attachCount = 0;
  List<String> attachFiles = [];

  final signatureOB = SignatureItem(key: "OBViewer", value: "OBViewer");
  @override
  void initState() {
    super.initState();
    if (widget.content != null && widget.content!.isNotEmpty) {
      var clist = html2Quill(widget.content!);
      _controller = fquill.QuillController(
        document: fquill.Document.fromJson(clist),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _controller = fquill.QuillController.basic();
    }
    if (widget.title != null && widget.title!.isNotEmpty) {
      titleValue.text = widget.title!;
    }
    if (widget.receivers != null && widget.receivers!.isNotEmpty) {
      receiveValue.text = widget.receivers!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    titleValue.dispose();
    receiveValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 0),
          child: TextField(
            controller: receiveValue,
            decoration: const InputDecoration(
              labelText: "收件人",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 0),
          child: Row(
            children: [
              // const Text("标题"),
              Expanded(
                child: TextField(
                  controller: titleValue,
                  decoration: const InputDecoration(
                    labelText: "标题",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (titleValue.text.isEmpty) {
                    showAlertDialog(context, "有问题", const Text("标题不能为空"),
                      actions1: TextButton(
                        onPressed: () { Navigator.of(context).pop(); },
                        child: const Text("知道了"),
                      )
                    );
                    return;
                  }
                  if (_controller.document.length==0) {
                    showAlertDialog(context, "有问题", const Text("内容不能为空"),
                      actions1: TextButton(
                        onPressed: () { Navigator.of(context).pop(); },
                        child: const Text("知道了"),
                      )
                    );
                    return;
                  }

                  if (receiveValue.text.isEmpty) {
                    showAlertDialog(context, "有问题", const Text("收件人不能为空"),
                      actions1: TextButton(
                        onPressed: () { Navigator.of(context).pop(); },
                        child: const Text("知道了"),
                      )
                    );
                    return;
                  }
                  List<String> rcvuidsStr = receiveValue.text.split(RegExp(r";|\s+|,|，|；"));
                  rcvuidsStr.removeWhere((element) => element.isEmpty);
                  var userRes = await bdwmUserInfoSearch(rcvuidsStr);
                  var rcvuids = <int>[];
                  if (userRes.success == false) {
                    if (!mounted) { return; }
                    await showAlertDialog(context, "发送中", const Text("查找用户失败"),
                      actions1: TextButton(
                        onPressed: () { Navigator.of(context).pop(); },
                        child: const Text("知道了"),
                      ),
                    );
                    return;
                  } else {
                    var uidx = 0;
                    for (var r in userRes.users) {
                      if (r == false) {
                        if (!mounted) { return; }
                        await showAlertDialog(context, "发送中", Text("用户${rcvuidsStr[uidx]}不存在"),
                          actions1: TextButton(
                            onPressed: () { Navigator.of(context).pop(); },
                            child: const Text("知道了"),
                          ),
                        );
                        return;
                      } else {
                        rcvuids.add(int.parse((r as IDandName).id));
                      }
                      uidx += 1;
                    }
                  }

                  var nSignature = signature?.value ?? "";
                  if (nSignature == "random") {
                    var maxS = widget.mailNewInfo.sigCount;
                    var randomI = math.Random().nextInt(maxS);
                    nSignature = randomI.toString();
                  } else if (nSignature == "OBViewer") {
                    nSignature = jsonEncode(signatureOBViewer);
                  }

                  var quillDelta = _controller.document.toDelta().toJson();
                  debugPrint(quillDelta.toString());
                  String mailContent = "";
                  try {
                    mailContent = quill2BDWMtext(quillDelta);
                  } catch (e) {
                    if (!mounted) { return; }
                    showAlertDialog(context, "内容格式错误", Text("$e\n请返回后截图找 onepiece 报bug"),
                      actions1: TextButton(
                        onPressed: () { Navigator.of(context).pop(); },
                        child: const Text("知道了"),
                      ),
                    );
                  }
                  if (mailContent.isEmpty) {
                    return;
                  }
                  if (widget.quote != null) {
                    var mailQuote = bdwmTextFormat(widget.quote!, mail: true);
                    // ...{}] [{}...
                    mailContent = "${mailContent.substring(0, mailContent.length-1)},${mailQuote.substring(1)}";
                  }
                  debugPrint(mailContent);

                  var nAttachPath = attachCount > 0 ? widget.mailNewInfo.attachpath : "";
                  bdwmCreateMail(
                    rcvuids: rcvuids, title: titleValue.text, content: mailContent, parentid: widget.parentid,
                    signature: nSignature, attachpath: nAttachPath)
                  .then((value) {
                    if (value.success == false) {
                      var errReason = "发送失败，请稍后重试";
                      if (value.error == -1) {
                        errReason = value.result ?? networkErrorText;
                      } else if (value.error == 9) {
                        errReason = "您的发信权已被封禁";
                      }
                      showAlertDialog(context, "发送失败", Text(errReason),
                        actions1: TextButton(
                          onPressed: () { Navigator.of(context).pop(); },
                          child: const Text("知道了"),
                        ),
                      );
                    } else {
                      var n = "";
                      var uidx = 0;
                      for (var u in rcvuids) {
                        if (value.sent.contains(u) == false) {
                          n += " ${rcvuidsStr[uidx]}";
                        }
                        uidx += 1;
                      }
                      var txt = "发送成功";
                      if (n.isNotEmpty) {
                        txt = "部分成功，发送给用户$n 的信件未发送成功";
                      }
                      showAlertDialog(context, "站内信", Text(txt),
                        actions1: TextButton(
                          onPressed: () { Navigator.of(context).pop(); },
                          child: const Text("知道了"),
                        ),
                      ).then((value) {
                        Navigator.of(context).pop();
                      },);
                    }
                  });
                },
                child: const Text("发送", style: TextStyle(color: bdwmPrimaryColor)),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1.0, style: BorderStyle.solid),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          margin: const EdgeInsets.only(left: 10, right: 10, top: 10),
          height: 200,
          child: fquill.QuillEditor.basic(
            controller: _controller,
            readOnly: false, // true for view only mode
            embedBuilders: [ImageEmbedBuilder()],
            // locale: const Locale('zh', 'CN'),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
          child: fquill.QuillToolbar.basic(
            controller: _controller,
            toolbarSectionSpacing: 1,
            showAlignmentButtons: false,
            showBoldButton: true,
            showUnderLineButton: true,
            showStrikeThrough: false,
            showDirection: false,
            showFontFamily: false,
            showFontSize: false,
            showHeaderStyle: false,
            showIndent: false,
            showLink: false,
            showSearchButton: false,
            showListBullets: false,
            showListNumbers: false,
            showListCheck: false,
            showDividers: false,
            showRightAlignment: false,
            showItalicButton: false,
            showCenterAlignment: false,
            showLeftAlignment: false,
            showJustifyAlignment: false,
            showSmallButton: false,
            showInlineCode: false,
            showCodeBlock: false,
            showColorButton: false,
            showRedo: false,
            showUndo: false,
            showBackgroundColorButton: false,
            customButtons: [
              fquill.QuillCustomButton(
                icon: Icons.color_lens,
                onTap: () {
                  showColorDialog(context, (bdwmRichText['fc'] as Map<String, int>).keys.toList())
                  .then((value) {
                    if (value == null) { return; }
                    _controller.formatSelection(fquill.ColorAttribute(value));
                  });
                }
              ),
              fquill.QuillCustomButton(
                icon: Icons.format_color_fill,
                onTap: () {
                  showColorDialog(context, (bdwmRichText['bc'] as Map<String, int>).keys.toList())
                  .then((value) {
                    if (value == null) { return; }
                    _controller.formatSelection(fquill.BackgroundAttribute(value));
                  });
                }
              ),
              fquill.QuillCustomButton(
                icon: Icons.image,
                onTap: () {
                  showTextDialog(context, "图片链接")
                  .then((value) {
                    if (value==null) { return; }
                    if (value.isEmpty) { return; }
                    var index = _controller.selection.baseOffset;
                    var length = _controller.selection.extentOffset - index;
                    _controller.replaceText(index, length, fquill.BlockEmbed.image(value), null);
                    _controller.formatText(index, 1, const fquill.StyleAttribute("mobileAlignment:topLeft;mobileWidth:150;mobileHeight:150"));
                  },);
                }
              ),
            ],
          ),
        ),
        if (widget.quote!=null)
          Container(
            margin: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 0),
            height: 100,
            child: SingleChildScrollView(
              child: HtmlComponent(widget.quote!),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 0),
          // alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                DropdownButton<SignatureItem>(
                  hint: const Text("签名档"),
                  icon: const Icon(Icons.arrow_drop_down),
                  value: signature,
                  items: [
                    DropdownMenuItem<SignatureItem>(
                      value: signatureOB,
                      child: const Text("OBViewer"),
                    ),
                    ...widget.mailNewInfo.signatureInfo.map<DropdownMenuItem<SignatureItem>>((SignatureItem item) {
                      return DropdownMenuItem<SignatureItem>(
                          value: item,
                          child: Text(item.key),
                        );
                      }).toList(),
                  ],
                  onChanged: (SignatureItem? value) {
                    setState(() {
                      signature = value!;
                    });
                  },
                ),
              TextButton(
                onPressed: () {
                  showUploadDialog(context, widget.mailNewInfo.attachpath, attachFiles)
                  .then((value) {
                    if (value == null) { return; }
                    var content = jsonDecode(value);
                    attachCount = content['count'];
                    attachFiles = [];
                    for (var f in content['files']) {
                      attachFiles.add(f);
                    }
                  },);
                },
                child: const Text("管理附件"),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class MailNewFuturePage extends StatefulWidget {
  final String? parentid;
  final String? receiver;
  const MailNewFuturePage({super.key, this.parentid, this.receiver});

  @override
  State<MailNewFuturePage> createState() => _MailNewFuturePageState();
}

class _MailNewFuturePageState extends State<MailNewFuturePage> {
  late CancelableOperation getDataCancelable;

  Future<MailNewInfo> getData() async {
    var url = "$v2Host/mail-new.php";
    if (widget.parentid != null) {
      url += "?parentid=${widget.parentid}";
    }
    var resp = await bdwmClient.get(url, headers: genHeaders2());
    if (resp == null) {
      return MailNewInfo.error(errorMessage: networkErrorText);
    }
    return parseMailNew(resp.body);
  }

  Future<String?> getMailQuote() async {
    var resp = await bdwmGetMailQuote(postid: widget.parentid!, mode: "full");
    if (!resp.success) {
      return networkErrorText;
    }
    return resp.result!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.parentid == null) {
      getDataCancelable = CancelableOperation.fromFuture(getData(), onCancel: () {
      },);
    } else {
      getDataCancelable = CancelableOperation.fromFuture(Future.wait([getData(), getMailQuote()]), onCancel: () {
      },);
    }
  }

  @override
  void dispose() {
    getDataCancelable.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getDataCancelable.value,
      builder: (context, snapshot) {
        // debugPrint(snapshot.connectionState.toString());
        if (snapshot.connectionState != ConnectionState.done) {
          // return const Center(child: CircularProgressIndicator());
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("错误：${snapshot.error}"),);
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text("错误：未获取数据"),);
        }
        MailNewInfo mailNewInfo;
        String? quoteText;
        if (widget.parentid == null) {
          mailNewInfo = snapshot.data as MailNewInfo;
        } else {
          mailNewInfo = (snapshot.data as List)[0];
          quoteText = (snapshot.data as List)[1];
        }
        if (mailNewInfo.errorMessage != null) {
          return Center(
            child: Text(mailNewInfo.errorMessage!),
          );
        }
        return MailNewPage(
          mailNewInfo: mailNewInfo, parentid: widget.parentid,
          title: mailNewInfo.title, receivers: widget.receiver ?? mailNewInfo.receivers,
          content: null, quote: quoteText,
        );
      }
    );
  }
}