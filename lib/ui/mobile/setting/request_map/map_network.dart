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
  late bool enableAesDecrypt;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.item?.url ?? '');
    enableAesDecrypt = widget.item?.enableAesDecrypt ?? false;
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  RequestMapItem getRequestMapItem() {
    RequestMapItem item = widget.item ?? RequestMapItem();
    item.url = urlController.text;
    item.enableAesDecrypt = enableAesDecrypt;
    return item;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '网络映射:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: urlController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: '映射的网络URL',
              hintText: 'https://api.example.com/endpoint',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations.cannotBeEmpty;
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          // AES解密开关
          Row(
            children: [
              Text(
                'AES解密:',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 10),
              SwitchWidget(
                value: enableAesDecrypt,
                onChanged: (value) => enableAesDecrypt = value,
                scale: 0.8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}