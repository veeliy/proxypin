import 'package:flutter/material.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/network/components/manager/request_map_manager.dart';
import 'package:proxypin/ui/component/widgets.dart';

class MobileMapNetwork extends StatefulWidget {
  final RequestMapItem? item;

  const MobileMapNetwork({super.key, this.item});

  @override
  State<MobileMapNetwork> createState() => MobileMapNetworkState();
}

class MobileMapNetworkState extends State<MobileMapNetwork> {
  late TextEditingController urlController;
  late TextEditingController statusCodeController;
  late bool enableAesDecrypt;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.item?.mappingUrl ?? '');
    enableAesDecrypt = widget.item?.enableAesDecrypt ?? false;
    final code = widget.item?.statusCode ?? '';
    statusCodeController = TextEditingController(text: code.toString());
  }

  @override
  void dispose() {
    urlController.dispose();
    statusCodeController.dispose();
    super.dispose();
  }

  RequestMapItem getRequestMapItem() {
    RequestMapItem item = widget.item ?? RequestMapItem();
    item.mappingUrl = urlController.text;
    item.enableAesDecrypt = enableAesDecrypt;
    return item;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 60, child: Text("状态码: ")),
            Expanded(
                child: TextFormField(
                    controller: statusCodeController,
                    style: const TextStyle(fontSize: 14),
                    onChanged: (code) {
                      int? statusCode = int.tryParse(code);
                      if (statusCode != null && statusCode >= 100 && statusCode <= 599) {
                        widget.item?.statusCode = statusCode;
                      } else {
                        widget.item?.statusCode = 200; // 默认值
                      }
                    },
                    decoration: InputDecoration(
                        hintText: '状态码',
                        constraints: const BoxConstraints(minHeight: 38),
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                        isDense: true,
                        border: const OutlineInputBorder()))),
            SizedBox(width: 18),
            Text('解密:'),
            const SizedBox(width: 10),
            Transform.scale(
                scale: 0.6,
                child: Switch(
                  value: enableAesDecrypt,
                  onChanged: (value) {
                    setState(() {
                      enableAesDecrypt = value;
                    });
                  },
                )),
          ],
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: urlController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: '映射URL',
            hintText: 'https://api.example.com/endpoint',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}