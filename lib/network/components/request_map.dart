/*
 * Copyright 2025 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:proxypin/network/components/interceptor.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/http/http_client.dart';
import 'package:proxypin/network/util/file_read.dart';

import 'js/script_engine.dart';
import 'manager/request_map_manager.dart';
import 'manager/script_manager.dart';

///  RequestRewriteComponent is a component that can rewrite the request before sending it to the server.
/// @author Hongen Wang
class RequestMapInterceptor extends Interceptor {
  static RequestMapInterceptor instance = RequestMapInterceptor._();
  static JavascriptRuntime? flutterJs;
  static Map<dynamic, dynamic> scriptSession = {};

  final managerInstance = RequestMapManager.instance;

  RequestMapInterceptor._();

  ///脚本上下文
  Map<String, dynamic> scriptContext(RequestMapRule rule) {
    return {'scriptName': rule.name, 'os': Platform.operatingSystem, 'session': scriptSession};
  }

  @override
  Future<HttpResponse?> execute(HttpRequest request) async {
    final manager = await managerInstance;
    if (!manager.enabled) {
      return null;
    }
    RequestMapRule? mapRule = manager.findMatch(request.requestUrl);
    if (mapRule == null) {
      return null;
    }
    var item = await manager.getMapItem(mapRule);
    if (item == null) {
      return null;
    }

    HttpResponse? response;
    if (mapRule.type == RequestMapType.local) {
      // 本地映射
      response = await mapLocalResponse(mapRule, item);
    } else if (mapRule.type == RequestMapType.script && item.script != null) {
      response = await executeScript(request, mapRule, item.script!);
    } else if (mapRule.type == RequestMapType.network && item.url != null) {
      // 网络映射
      response = await mapNetworkResponse(request, mapRule, item);
    }

    if (response == null) {
      return null;
    }

    response.request = request;
    request.response = response;
    return response;
  }

  /// 网络映射响应
  Future<HttpResponse?> mapNetworkResponse(HttpRequest request, RequestMapRule rule, RequestMapItem item) async {
    if (item.url == null || item.url!.isEmpty) {
      return null;
    }

    try {
      // 创建一个完整的 GET 请求
      Uri targetUri = Uri.parse(item.url!);
      HttpRequest networkRequest = HttpRequest(HttpMethod.get, item.url!);

      // 设置必要的请求头
      networkRequest.headers.set('Host', '${targetUri.host}${targetUri.hasPort ? ':${targetUri.port}' : ''}');
      networkRequest.headers.set('User-Agent', 'ProxyPin-NetworkMapper/1.0');
      networkRequest.headers.set('Accept', '*/*');
      networkRequest.headers.set('Connection', 'close');

      // 可选：从原始请求中复制一些有用的头部（但要小心避免冲突）
      String? originalUserAgent = request.headers.get('User-Agent');
      if (originalUserAgent != null && originalUserAgent.isNotEmpty) {
        networkRequest.headers.set('User-Agent', originalUserAgent);
      }

      // 使用 proxyRequest 方法发送请求，它处理得更完整
      HttpResponse response = await HttpClients.proxyRequest(
          networkRequest,
          timeout: const Duration(seconds: 10)
      );

      return response;
    } catch (e) {
      // 如果请求失败，返回错误响应
      HttpResponse errorResponse = HttpResponse(HttpStatus(500, 'Network mapping failed: $e'));
      errorResponse.headers.set('Content-Type', 'text/plain; charset=utf-8');
      errorResponse.body = 'Network mapping error: $e'.codeUnits;

      return errorResponse;
    }
  }

  /// 重写响应
  Future<HttpResponse> mapLocalResponse(RequestMapRule rule, RequestMapItem item) async {
    HttpResponse response = HttpResponse(HttpStatus.valueOf(item.statusCode ?? 200));
    item.headers?.forEach((key, value) {
      response.headers.set(key, value);
    });
    if (item.bodyType == MapBodyType.file.name) {
      if (item.bodyFile == null) return response;
      response.body = await FileRead.readFile(item.bodyFile!);
    } else if (item.body != null) {
      response.body =
          response.charset == 'utf-8' || response.charset == 'utf8' ? utf8.encode(item.body!) : item.body?.codeUnits;
    }
    return response;
  }

  /// script执行
  Future<HttpResponse?> executeScript(HttpRequest request, RequestMapRule rule, String script) async {
    flutterJs ??= await JavaScriptEngine.getJavaScript(consoleLog: ScriptManager.consoleLog);
    var context = jsonEncode(scriptContext(rule));
    var jsRequest = jsonEncode(await JavaScriptEngine.convertJsRequest(request));

    var jsResult = await flutterJs!.evaluateAsync(
        """var request = $jsRequest, context = $context;  request['scriptContext'] = context; $script\n  onRequest(context, request)""");
    // print("response: ${jsResult.isPromise} ${jsResult.isError} ${jsResult.rawResult}");
    var result = await JavaScriptEngine.jsResultResolve(flutterJs!, jsResult);
    if (result == null) {
      return null;
    }

    if (result['scriptContext']?['session'] != null) {
      scriptSession = result['scriptContext']['session'];
    }
    HttpResponse response = HttpResponse(HttpStatus.valueOf(200));
    response = JavaScriptEngine.convertHttpResponse(response, result);
    return response;
  }
}
