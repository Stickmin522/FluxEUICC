import 'package:flutter/material.dart';

import 'controller.dart';
import 'design.dart';
import 'strings.dart';
import 'tools_pages.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int taps = 0;
  DateTime lastTap = DateTime(2000);
  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 28, 4, 14),
    child: Text(
      context.s(title),
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  Widget _toggle(BuildContext context, String key, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(context.s(title)),
        subtitle: Text(context.s('${title}_desc')),
        value: widget.controller.preferences[key] == true,
        onChanged: (value) => widget.controller.guard(
          () => widget.controller.setPreference(key, value),
        ),
      ),
    ),
  );

  Widget _link(
    BuildContext context,
    String title,
    String? subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppBar(
        title: Text(
          context.s('pref_settings'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            _section(context, 'pref_notifications'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                context.s('pref_notifications_desc'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _toggle(
              context,
              'notificationDownload',
              'pref_notifications_download',
            ),
            _toggle(context, 'notificationDelete', 'pref_notifications_delete'),
            _toggle(context, 'notificationSwitch', 'pref_notifications_switch'),
            _section(context, 'pref_advanced'),
            _toggle(
              context,
              'disableSafeguard',
              'pref_advanced_disable_safeguard_removable_esim',
            ),
            _toggle(context, 'verboseLogging', 'pref_advanced_verbose_logging'),
            _toggle(context, 'forceTpdu', 'pref_advanced_force_tpdu_mode'),
            _link(
              context,
              context.s('pref_advanced_http_proxy'),
              '${widget.controller.preferences['httpProxy'] ?? ''}',
              Icons.public,
              () async {
                final value = await editValue(
                  context,
                  context.s('pref_advanced_http_proxy'),
                  value: '${widget.controller.preferences['httpProxy'] ?? ''}',
                  message: context.s('pref_advanced_http_proxy_dialog_message'),
                );
                if (value != null) {
                  await widget.controller.guard(
                    () => widget.controller.setPreference('httpProxy', value),
                  );
                }
              },
            ),
            _link(
              context,
              context.s('ui_language'),
              languageLabel(
                context,
                '${widget.controller.configuration['language'] ?? ''}',
                '${widget.controller.configuration['systemLocale'] ?? 'en-US'}',
              ),
              Icons.translate,
              () => openPage(
                context,
                LanguagePage(controller: widget.controller),
              ),
            ),
            _link(
              context,
              context.s('pref_advanced_logs'),
              context.s('pref_advanced_logs_desc'),
              Icons.article_outlined,
              () => openPage(context, LogsPage(controller: widget.controller)),
            ),
            if (widget.controller.preferences['developer'] == true) ...[
              _section(context, 'pref_developer'),
              _toggle(
                context,
                'refreshAfterSwitch',
                'pref_developer_refresh_after_switch',
              ),
              _toggle(
                context,
                'unfiltered',
                'pref_developer_unfiltered_profile_list',
              ),
              _toggle(
                context,
                'ignoreTls',
                'pref_developer_ignore_tls_certificate',
              ),
              _link(
                context,
                context.s('pref_developer_es10x_mss'),
                '${widget.controller.preferences['mss']}',
                Icons.speed,
                () async {
                  final value = await showDialog<int>(
                    context: context,
                    builder: (dialog) => SimpleDialog(
                      title: Text(context.s('pref_developer_es10x_mss')),
                      children: [
                        for (final value in [255, 63])
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(dialog, value),
                            child: Text('$value'),
                          ),
                      ],
                    ),
                  );
                  if (value != null) {
                    await widget.controller.guard(
                      () => widget.controller.setPreference('mss', value),
                    );
                  }
                },
              ),
              _link(
                context,
                context.s('pref_developer_isdr_aid_list'),
                context.s('pref_developer_isdr_aid_list_desc'),
                Icons.code,
                () => openPage(
                  context,
                  AidListPage(controller: widget.controller),
                ),
              ),
            ],
            _section(context, 'pref_info'),
            _link(
              context,
              context.s('pref_info_app_version'),
              '${widget.controller.configuration['version'] ?? '2.0'}',
              Icons.info_outline,
              () {
                final now = DateTime.now();
                taps = now.difference(lastTap).inMilliseconds > 1000
                    ? 1
                    : taps + 1;
                lastTap = now;
                if (taps >= 7 &&
                    widget.controller.preferences['developer'] != true) {
                  widget.controller.guard(() async {
                    await widget.controller.setPreference('developer', true);
                    widget.controller.showMessage?.call(
                      'developer_options_enabled',
                    );
                  });
                }
              },
            ),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ARA-M SHA-1',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: context.s('ui_copy'),
                        onPressed: () => copyValue(
                          context,
                          '${widget.controller.configuration['fingerprint'] ?? ''}',
                          'toast_ara_m_copied',
                        ),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.controller.configuration['fingerprint'] ?? ''}',
                    textDirection: TextDirection.ltr,
                    softWrap: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _link(
              context,
              context.s('pref_info_source_code'),
              'github.com/Stickmin522/FluxEUICC',
              Icons.open_in_new,
              () => widget.controller.guard(() async {
                await widget.controller.invoke('source');
              }),
            ),
          ],
        ),
      ),
    ],
  );
}

String languageLabel(BuildContext context, String tag, String system) {
  if (tag.isNotEmpty) {
    return languages[tag] ?? languages[tag.split('-').first] ?? 'English';
  }
  final supported = languages.keys.any(
    (value) => value.split('-').first == system.split('-').first,
  );
  return '${context.s('pref_advanced_language_system_default')}${supported ? '' : ' (English)'}';
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.controller});
  final EuiccController controller;
  @override
  Widget build(BuildContext context) {
    final selected = '${controller.configuration['language'] ?? ''}';
    final system = '${controller.configuration['systemLocale'] ?? 'en-US'}';
    final options = {'': languageLabel(context, '', system), ...languages};
    return FlowPage(
      title: context.s('ui_language'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final entry in options.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                active: selected == entry.key,
                onTap: () => controller.guard(() async {
                  await controller.invoke('language', {'tag': entry.key});
                  controller.setLanguage(entry.key);
                  if (context.mounted) Navigator.pop(context);
                }),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      selected == entry.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected == entry.key
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AidListPage extends StatefulWidget {
  const AidListPage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<AidListPage> createState() => _AidListPageState();
}

class _AidListPageState extends State<AidListPage> {
  late final editor = TextEditingController(
    text: '${widget.controller.preferences['aidList'] ?? ''}',
  );
  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('isdr_aid_list'),
    actions: [
      IconButton(
        tooltip: context.s('isdr_aid_list_reset'),
        onPressed: () => widget.controller.guard(() async {
          await widget.controller.setPreference('aidList', null);
          editor.text = '${widget.controller.preferences['aidList']}';
        }),
        icon: const Icon(Icons.restart_alt),
      ),
    ],
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: editor,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          FlowButton(
            label: context.s('ui_save'),
            onPressed: () => widget.controller.guard(() async {
              await widget.controller.setPreference('aidList', editor.text);
              widget.controller.showMessage?.call('isdr_aid_list_saved');
            }),
          ),
        ],
      ),
    ),
  );
}
