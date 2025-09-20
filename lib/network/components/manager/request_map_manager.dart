import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/http/http_client.dart';

import '../../../utils/encryption_service.dart';
import '../../util/logger.dart';
import '../../util/random.dart';

class RequestMapManager {
  static RequestMapManager? _instance;

  static String separator = Platform.pathSeparator;

  RequestMapManager._internal();

  final Map<RequestMapRule, RequestMapItem> _mapItemsCache = {};

  bool enabled = true;

  //存储所有的请求映射规则
  List<RequestMapRule> rules = [];

  ///单例
  static Future<RequestMapManager> get instance async {
    if (_instance == null) {
      _instance = RequestMapManager._internal();
      await _instance?.reloadConfig();
    }
    return _instance!;
  }

  //添加规则
  Future<void> addRule(RequestMapRule rule, RequestMapItem item) async {
    final path = await homePath();
    String itemPath = "${separator}request_map$separator${RandomUtil.randomString(16)}.json";
    var file = File(path + itemPath);
    await file.create(recursive: true);
    final itemJson = jsonEncode(item.toJson());
    file.writeAsString(itemJson);

    rule.itemPath = itemPath;
    _mapItemsCache[rule] = item;
    rules.add(rule);

    await flushConfig();
  }

  //update rule
  Future<void> updateRule(RequestMapRule rule, RequestMapItem item) async {
    rule.updatePathReg();
    if (rule.itemPath != null) {
      final path = await homePath();
      var file = File('$path${rule.itemPath}');
      await file.writeAsString(jsonEncode(item.toJson()));
    }
    _mapItemsCache[rule] = item;
    await flushConfig();
  }

  //删除规则
  Future<void> deleteRule(int index) async {
    var item = rules.removeAt(index);
    final home = await homePath();
    File(home + item.itemPath!).delete();
  }

  //根据url和类型查找匹配的规则
  RequestMapRule? findMatch(String url) {
    for (var rule in rules) {
      if (rule.match(url)) {
        return rule;
      }
    }
    return null;
  }

  Future<RequestMapItem?> getMapItem(RequestMapRule rule) async {
    if (_mapItemsCache.containsKey(rule)) {
      return _mapItemsCache[rule];
    }

    if (rule.itemPath != null) {
      final path = await homePath();
      var file = File('$path$separator${rule.itemPath}');
      if (await file.exists()) {
        var content = await file.readAsString();
        if (content.isNotEmpty) {
          var item = RequestMapItem.fromJson(jsonDecode(content));
          _mapItemsCache[rule] = item;
          return item;
        }
      }
    }
    return null;
  }

  static String? _homePath;

  static Future<String> homePath() async {
    if (_homePath != null) {
      return _homePath!;
    }

    if (Platform.isMacOS) {
      _homePath = await DesktopMultiWindow.invokeMethod(0, "getApplicationSupportDirectory");
    } else {
      _homePath = await getApplicationSupportDirectory().then((it) => it.path);
    }
    return _homePath!;
  }

  static Future<File> get _path async {
    final path = await homePath();
    var file = File('$path${Platform.pathSeparator}request_map.json');
    if (!await file.exists()) {
      await file.create();
    }
    return file;
  }

  ///重新加载配置
  Future<void> reloadConfig() async {
    List<RequestMapRule> list = [];
    var file = await _path;
    logger.d("reload request map config from ${file.path}");

    if (await file.exists()) {
      var content = await file.readAsString();
      if (content.isEmpty) {
        return;
      }
      var config = jsonDecode(content);
      enabled = config['enabled'] == true;
      for (var entry in config['list']) {
        list.add(RequestMapRule.fromJson(entry));
      }
    }
    rules = list;
    _mapItemsCache.clear();
  }

  ///重新加载配置
  Future<void> reloadConfigFromNetwork(String url) async {
    try {
      Uri targetUri = Uri.parse(url);
      HttpRequest networkRequest = HttpRequest(HttpMethod.get, url);

      // 设置必要的请求头
      networkRequest.headers.set('Host', '${targetUri.host}${targetUri.hasPort ? ':${targetUri.port}' : ''}');
      networkRequest.headers.set('User-Agent', 'ProxyPin-NetworkMapper/1.0');
      networkRequest.headers.set('Accept', '*/*');
      networkRequest.headers.set('Connection', 'close');

      // 使用 proxyRequest 方法发送请求，它处理得更完整
      HttpResponse response = await HttpClients.proxyRequest(
          networkRequest,
          timeout: const Duration(seconds: 10)
      );

      String originalBody = await response.decodeBodyString();
      final dynamic jsonData = json.decode(originalBody);
      final dynamic decrypted = EncryptionService.decryptJson(jsonData);
      // 转换为字符串并解析JSON
      final dynamic data = json.decode(utf8.decode(decrypted));
      List<dynamic> list = data is List<dynamic> ? data : [];
      rules.clear();
      for (var item in list) {
        var mapRule = RequestMapRule.fromJson(item);
        var requestMapItem = RequestMapItem.fromJson(item['item']);
        await addRule(mapRule, requestMapItem);
      }

    } catch (e) {
      logger.e("reload request map config from network failed: $e");
    }
  }

  ///保存配置
  Future<void> flushConfig() async {
    var file = await _path;
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    var config = {
      'enabled': enabled,
      'list': rules.map((e) => e.toJson()).toList(),
    };

    await file.writeAsString(jsonEncode(config));
  }
}

enum RequestMapType {
  local("本地"),
  script("脚本"),
  network("网络"),
  ;

  //名称
  final String label;

  const RequestMapType(this.label);

  static RequestMapType fromName(String name) {
    return values.firstWhere((element) => element.name == name || element.label == name);
  }
}

class RequestMapRule {
  bool enabled;
  RequestMapType type;

  String? name;
  String url;
  RegExp _urlReg;
  String? itemPath;

  RequestMapRule({this.enabled = true, this.name, required this.url, required this.type, this.itemPath})
      : _urlReg = RegExp(url.replaceAll("*", ".*").replaceFirst('?', '\\?'));

  bool match(String url) {
    if (enabled) {
      return _urlReg.hasMatch(url);
    }
    return false;
  }

  /// 从json中创建
  factory RequestMapRule.fromJson(Map<dynamic, dynamic> map) {
    return RequestMapRule(
        enabled: map['enabled'] == true,
        name: map['name'],
        url: map['url'],
        type: RequestMapType.fromName(map['type']),
        itemPath: map['itemPath']);
  }

  void updatePathReg() {
    _urlReg = RegExp(url.replaceAll("*", ".*").replaceFirst('?', '\\?'));
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'url': url,
      'type': type.name,
      'itemPath': itemPath,
    };
  }
}

class RequestMapItem {
  String? script;

  int? statusCode;
  Map<String, String>? headers;

  //body
  String? body;

  String? bodyType;

  String? bodyFile;
  
  // network mapping url
  String? mappingUrl;
  
  // AES解密开关
  bool? enableAesDecrypt;

  RequestMapItem({this.script, this.statusCode, this.headers, this.body, this.bodyType, this.bodyFile, this.mappingUrl, this.enableAesDecrypt});

  /// 从json中创建
  factory RequestMapItem.fromJson(Map<dynamic, dynamic> map) {
    return RequestMapItem(
      script: map['script'],
      statusCode: map['statusCode'],
      headers: (map['headers'] as Map?)?.cast<String, String>(),
      body: map['body'],
      bodyType: map['bodyType'],
      bodyFile: map['bodyFile'],
      mappingUrl: map['mappingUrl'],
      enableAesDecrypt: map['enableAesDecrypt'],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'script': script,
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'bodyType': bodyType,
      'bodyFile': bodyFile,
      'mappingUrl': mappingUrl,
      'enableAesDecrypt': enableAesDecrypt,
    };
  }
}

enum MapBodyType {
  text("文本"),
  file("文件");

  final String label;

  const MapBodyType(this.label);
}
