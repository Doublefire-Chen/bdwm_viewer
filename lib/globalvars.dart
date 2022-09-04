import 'dart:convert';
import 'dart:io';

// import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const bbsHost = "https://bbs.pku.edu.cn";
const v2Host = "https://bbs.pku.edu.cn/v2";
// const bbsHost = "";
// const v2Host = "";
const defaultAvator = "/v2/images/user/portrait-neu.png";
const networkErrorText = "网络问题，请稍后重试";

List<String> parseCookie(String cookie) {
  var pattern1 = "skey=";
  var pattern2 = "uid=";
  var pos1 = cookie.lastIndexOf(pattern1);
  if (pos1 == -1) {
    return <String>[];
  }
  var pos2 = cookie.lastIndexOf(pattern2);
  var pos1sc = cookie.indexOf(";", pos1);
  var pos2sc = cookie.indexOf(";", pos2);
  var skey = cookie.substring(pos1+5, pos1sc);
  var uid = cookie.substring(pos2+4, pos2sc);
  return <String>[uid, skey];
}

class Uinfo {
  String skey = "a946e957f047df88";
  String uid = "15265";
  String username = "";
  bool login = false;
  String storage = "bdwmusers.json";

  Uinfo({required this.skey, required this.uid, required this.username});
  Uinfo.empty();
  Uinfo.initFromFile() {
    init();
  }

  String gist() {
    return "$username($uid): $skey ${login == true? 'online' : 'offline'}";
  }

  void setInfo(String skey, String uid, String username) {
    this.skey = skey;
    this.uid = uid;
    this.username = username;
    login = true;
    update();
  }

  Future<bool> init() async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    String filename = "$dir/$storage";
    // debugPrint(filename);
    void writeInit() {
      var file = File(filename).openWrite();
      Map<String, Object> content = <String, Object>{
        "users": [{
            "name": "guest",
            "skey": "a946e957f047df88",
            "uid": "15265",
            "login": false
        }],
        "primary": 0
      };
      file.write(jsonEncode(content));
      file.close();
    }
    if (File(filename).existsSync()) {
      var content = File(filename).readAsStringSync();
      if (content.isEmpty) {
        writeInit();
      }
      var jsonContent = jsonDecode(content);
      uid = jsonContent['users'][0]['uid'];
      skey = jsonContent['users'][0]['skey'];
      username = jsonContent['users'][0]['name'];
      login = jsonContent['users'][0]['login'];
    } else {
      writeInit();
    }
    return true;
  }

  void update() async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    String filename = "$dir/$storage";
    var content = File(filename).readAsStringSync();
    var jsonContent = jsonDecode(content);
    jsonContent['users'][0]['uid'] = uid;
    jsonContent['users'][0]['skey'] = skey;
    jsonContent['users'][0]['name'] = username;
    jsonContent['users'][0]['login'] = login;
    var file = File(filename).openWrite();
    file.write(jsonEncode(jsonContent));
    file.close();
  }

  void checkAndLogout(cookie) {
    if (login == false) {
      return;
    }
    List<String> res = parseCookie(cookie);
    if (res.isEmpty) {
      return;
    }
    String newUid = res[0];
    String newSkey = res[1];
    if (newUid != uid) {
      uid = newUid;
      skey = newSkey;
      login = false;
      update();
    } else if (newSkey != skey) {
      uid = newUid;
      skey = newSkey;
      login = true;
      update();
    }
  }

  void setLogout() {
    login = false;
    username = "guest";
    update();
  }
}

Map<String, String> genHeaders() {
  return <String, String>{
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
    "accept-language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
    "cache-control": "max-age=0",
    "sec-ch-ua": "\"Chromium\";v=\"104\", \" Not A;Brand\";v=\"99\", \"Microsoft Edge\";v=\"104\"",
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "\"Windows\"",
    "sec-fetch-dest": "document",
    "sec-fetch-mode": "navigate",
    "sec-fetch-site": "same-origin",
    "sec-fetch-user": "?1",
    "upgrade-insecure-requests": "1",
    "cookie": "mode=topic; mode=topic; favorite_mode=list; favorite_mode=list; skey=${globalUInfo.skey}; uid=${globalUInfo.uid}",
    "Referer": "https://bbs.pku.edu.cn/v2/home.php",
    "Referrer-Policy": "strict-origin-when-cross-origin"
  };
}

Map<String, String> genHeaders2() {
  return <String, String>{
    "accept": "*/*",
    "accept-language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
    "sec-ch-ua": "\"Chromium\";v=\"104\", \" Not A;Brand\";v=\"99\", \"Microsoft Edge\";v=\"104\"",
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "\"Windows\"",
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-origin",
    "x-requested-with": "XMLHttpRequest",
    "cookie": "mode=topic; mode=topic; ; favorite_mode=list; favorite_mode=list; skey=${globalUInfo.skey}; uid=${globalUInfo.uid}",
    "Referer": "https://bbs.pku.edu.cn/",
    "Referrer-Policy": "strict-origin-when-cross-origin"
  };
}

var globalUInfo = Uinfo.empty();
