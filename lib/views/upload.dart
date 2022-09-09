import 'dart:math' show min;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// import '../globalvars.dart';
import '../utils.dart' show checkAndRequestPermission;
import "./utils.dart";
import './constants.dart';
import '../bdwm/upload.dart';

class UploadFileStatus {
  String name = "";
  String status = "";

  UploadFileStatus.empty();
  UploadFileStatus({
    required this.name,
    required this.status,
  });
}

class UploadDialogBody extends StatefulWidget {
  final String attachpath;
  const UploadDialogBody({super.key, required this.attachpath});

  @override
  State<UploadDialogBody> createState() => _UploadDialogBodyState();
}

class _UploadDialogBodyState extends State<UploadDialogBody> {
  // List<UploadFileStatus> filenames = [UploadFileStatus(name: "haha.jpg", status: "ok")];
  List<UploadFileStatus> filenames = [];
  int count = 0;
  @override
  Widget build(BuildContext context) {
    final dSize = MediaQuery.of(context).size;
    final dWidth = dSize.width;
    final dHeight = dSize.height;
    return SizedBox(
      width: min(260, dWidth*0.8),
      height: min(300, dHeight*0.8),
      child: Column(
        children: [
          TextButton(
            onPressed: () {
              checkAndRequestPermission(Permission.storage)
              .then((couldDoIt) {
                if (!couldDoIt) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("没有文件权限"), duration: const Duration(milliseconds: 1000),),
                  );
                  return;
                }
                FilePicker.platform.pickFiles()
                .then((res) {
                  if (res == null) { return; }
                  if (res.count == 0) { return; }
                  for (var f in res.files) {
                    if (f.path == null) { continue; }
                    bdwmUpload(widget.attachpath, f.path!)
                    .then((uploadRes) {
                      if (uploadRes.success == true) {
                        debugPrint(uploadRes.name);
                        debugPrint(uploadRes.url);
                        setState(() {
                          count = count + 1;
                          filenames.add(UploadFileStatus(name: uploadRes.name!, status: "ok"));
                        });
                      }
                    });
                  }
                });
              });
            },
            child: const Text("选取文件"),
          ),
          Expanded(
            child: ListView(
              children: filenames.map((e) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(e.name),
                    const Icon(Icons.delete, color: bdwmPrimaryColor,),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showUploadDialog(BuildContext context, String attachpath) {
  var key = GlobalKey<_UploadDialogBodyState>();
  return showAlertDialog(context, "管理附件", UploadDialogBody(key: key, attachpath: attachpath,),
    actions1: TextButton(
      onPressed: () {
        Navigator.of(context).pop(key.currentState!.count.toString());
      },
      child: const Text("确认"),
    ),
  );
}