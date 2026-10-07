import 'package:flutter/material.dart';

import 'controller.dart';
import 'design.dart';
import 'strings.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  late Future<dynamic> data = widget.controller.invoke(
    'info',
    widget.controller.cardArgs,
  );
  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('euicc_info'),
    actions: [
      IconButton(
        tooltip: context.s('ui_retry'),
        onPressed: () => setState(
          () => data = widget.controller.invoke(
            'info',
            widget.controller.cardArgs,
          ),
        ),
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: StatePanel(title: context.s('profile_read_failed')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final item in jsonList(snapshot.data))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  onTap: () => copyValue(context, '${item['value']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.s('${item['key']}'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        '${item['value']}',
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<dynamic> data = widget.controller.invoke(
    'notifications',
    widget.controller.cardArgs,
  );
  bool acting = false;
  Future<void> refresh() async {
    setState(
      () => data = widget.controller.invoke(
        'notifications',
        widget.controller.cardArgs,
      ),
    );
    await data;
  }

  Future<void> action(Json item, bool delete) async {
    if (acting) return;
    if (delete &&
        !await confirmAction(
          context,
          context.s('profile_notification_delete'),
          '${item['name']} · #${item['sequence']}',
        )) {
      return;
    }
    setState(() => acting = true);
    await widget.controller.guard(() async {
      await widget.controller.invoke('notification', {
        ...widget.controller.cardArgs,
        'sequence': item['sequence'],
        'delete': delete,
      });
      if (mounted) await refresh();
    });
    if (mounted) setState(() => acting = false);
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('profile_notifications'),
    actions: [
      IconButton(
        tooltip: context.s('notification_help'),
        icon: const Icon(Icons.help_outline),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(context.s('profile_notifications')),
            content: SingleChildScrollView(
              child: Text(context.s('profile_notifications_help')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(context.s('ui_done')),
              ),
            ],
          ),
        ),
      ),
    ],
    body: FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: StatePanel(
              title: context.s('operation_failed'),
              action: TextButton(
                onPressed: refresh,
                child: Text(context.s('ui_retry')),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = jsonList(snapshot.data);
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (acting) const LinearProgressIndicator(),
              if (items.isEmpty)
                StatePanel(
                  title: context.s('ui_empty_notifications'),
                  icon: Icons.notifications_none,
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item['name']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<bool>(
                              enabled: !acting,
                              tooltip: context.s('menu_actions'),
                              onSelected: (delete) => action(item, delete),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: false,
                                  child: MenuLabel(
                                    icon: Icons.send_outlined,
                                    label: context.s(
                                      'profile_notification_process',
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: true,
                                  child: MenuLabel(
                                    icon: Icons.delete_outline_rounded,
                                    label: context.s(
                                      'profile_notification_delete',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${context.s('profile_notification_operation_${item['operation'] == 'install' ? 'download' : item['operation']}')} · #${item['sequence']}',
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          '${item['address']}',
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ICCID: ${item['iccid']}',
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.controller, this.supplied});
  final EuiccController controller;
  final String? supplied;
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late Future<String?> data = widget.supplied == null
      ? widget.controller.invoke<String>('logs')
      : Future.value(widget.supplied);
  String text = '';
  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('pref_advanced_logs'),
    actions: [
      IconButton(
        tooltip: context.s('ui_retry'),
        icon: const Icon(Icons.refresh),
        onPressed: () =>
            setState(() => data = widget.controller.invoke<String>('logs')),
      ),
      IconButton(
        tooltip: context.s('ui_save'),
        icon: const Icon(Icons.save_alt),
        onPressed: () => widget.controller.guard(() async {
          final saved = await widget.controller.invoke<bool>('export', {
            'text': text,
          });
          if (saved == true &&
              context.mounted &&
              await confirmAction(
                context,
                context.s('pref_advanced_logs'),
                context.s('logs_saved_message'),
              )) {
            await widget.controller.invoke('shareExport');
          }
        }),
      ),
    ],
    body: FutureBuilder<String?>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StatePanel(title: context.s('operation_failed'));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        text = snapshot.data ?? '';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: GlassPanel(
            child: SelectableText(
              text.split('\n').reversed.take(256).toList().reversed.join('\n'),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class CompatibilityPage extends StatefulWidget {
  const CompatibilityPage({
    super.key,
    required this.controller,
    this.initial = false,
  });
  final EuiccController controller;
  final bool initial;
  @override
  State<CompatibilityPage> createState() => _CompatibilityPageState();
}

class _CompatibilityPageState extends State<CompatibilityPage> {
  late Future<dynamic> data = widget.controller.invoke('compatibility');
  bool skip = false;
  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('compatibility_check'),
    actions: [
      IconButton(
        tooltip: context.s('ui_retry'),
        onPressed: () =>
            setState(() => data = widget.controller.invoke('compatibility')),
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: StatePanel(title: context.s('operation_failed')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = json(snapshot.data);
        final readers = result['readers'] as List;
        final isdr = result['isdr'] as List;
        final conclusion = isdr.isNotEmpty
            ? 'quick_compatibility_compatible'
            : readers.isNotEmpty
            ? 'quick_compatibility_unconfirmed'
            : result['usb'] == true
            ? 'quick_compatibility_not_compatible_but_usb'
            : 'quick_compatibility_not_compatible';
        final checks = <String, bool?>{
          'quick_compatibility_check_omapi': result['omapi'] == true,
          'quick_compatibility_check_sim_slot': readers.isNotEmpty,
          'quick_compatibility_check_isdr': isdr.isNotEmpty
              ? true
              : readers.isNotEmpty
              ? null
              : false,
          'quick_compatibility_check_usb_host': result['usb'] == true,
          'quick_compatibility_check_ara_m': null,
        };
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GlassPanel(
              active: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    size: 38,
                    color: flowPurple,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.s(conclusion, ['OpenEUICC']),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('${result['device']}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassPanel(
              child: Column(
                children: [
                  for (final check in checks.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(context.s(check.key))),
                          const SizedBox(width: 18),
                          Semantics(
                            label: context.s(
                              check.value == true
                                  ? 'quick_compatibility_status_supported'
                                  : check.value == false
                                  ? 'quick_compatibility_status_not_detected'
                                  : 'quick_compatibility_status_not_verified',
                            ),
                            child: Text(
                              check.value == true
                                  ? '✓'
                                  : check.value == false
                                  ? '×'
                                  : '—',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(context.s('quick_compatibility_check_explanation')),
            if (readers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.s('quick_compatibility_result_slots', [
                  readers.join(', '),
                ]),
              ),
            ],
            if (isdr.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.s('quick_compatibility_result_slots_isdr', [
                  isdr.join(', '),
                ]),
              ),
            ],
            if (widget.initial) ...[
              const SizedBox(height: 20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.s('quick_compatibility_skip')),
                value: skip,
                onChanged: (value) => setState(() => skip = value!),
              ),
              const SizedBox(height: 20),
              FlowButton(
                label: context.s('ui_continue'),
                onPressed: () => widget.controller.guard(() async {
                  await widget.controller.invoke('skipCompatibility', {
                    'skip': skip || isdr.isNotEmpty,
                  });
                  if (context.mounted) Navigator.pop(context);
                }),
              ),
            ],
          ],
        );
      },
    ),
  );
}
