import 'package:flutter/material.dart';
import 'package:proxypin/network/bin/configuration.dart';

class RuleSyncSettingDialog extends StatefulWidget {
  final Configuration configuration;

  const RuleSyncSettingDialog({super.key, required this.configuration});

  @override
  State<StatefulWidget> createState() {
    return _RuleSyncSettingDialogState();
  }
}

class _RuleSyncSettingDialogState extends State<RuleSyncSettingDialog> {
  late TextEditingController urlController;
  late String networkRuleSyncUrl;

  @override
  initState() {
    super.initState();
    urlController = TextEditingController();
    networkRuleSyncUrl = widget.configuration.networkRuleSyncUrl ?? '';
    urlController.text = networkRuleSyncUrl;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        title: Text('网络导入设置', style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消')),
          TextButton(
              onPressed: () async {
                submit();
              },
              child: Text('确认'))
        ],
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: urlController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://api.example.com/endpoint',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '从指定地址获取导入规则，设置好之后可以直接点击刷新；网络导入会覆盖当前规则，导入前确认所有数据已保存。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ));
  }

  Future<void> submit() async {
    widget.configuration.networkRuleSyncUrl = urlController.text.trim();
    widget.configuration.flushConfig();

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}