import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'controller.dart';
import 'design.dart';
import 'strings.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key, required this.controller, this.lpa});
  final EuiccController controller;
  final String? lpa;
  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final code = TextEditingController();
  bool processing = false;
  @override
  void initState() {
    super.initState();
    if (widget.lpa != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _parse(widget.lpa!));
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _parse(String input) async {
    if (processing) return;
    setState(() => processing = true);
    await widget.controller.guard(() async {
      final parsed = json(
        await widget.controller.invoke('parse', {'input': input}),
      );
      if (mounted) {
        await openPage(
          context,
          DownloadDetailsPage(controller: widget.controller, details: parsed),
        );
      }
    });
    if (mounted) setState(() => processing = false);
  }

  Future<void> _image() => widget.controller.guard(() async {
    final value = await widget.controller.invoke<String>('image');
    if (value != null && mounted) await _parse(value);
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final card = widget.controller.selected;
      return FlowPage(
        title: context.s('home_add_profile'),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.controller.cards.length > 1) ...[
              GlassPanel(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<int>(
                  initialValue: widget.controller.cards.indexWhere(
                    (value) => EuiccController.sameCard(card, value),
                  ),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.s('download_wizard_slot_select'),
                  ),
                  items: [
                    for (var i = 0; i < widget.controller.cards.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('${widget.controller.cards[i]['title']}'),
                      ),
                  ],
                  onChanged: widget.controller.busy
                      ? null
                      : (index) => widget.controller.select(
                          widget.controller.cards[index!],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (card == null)
              StatePanel(
                title: context.s('empty_heading'),
                subtitle: context.s('empty_hint'),
              )
            else ...[
              if (card['freeSpace'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    '${card['title']} · ${context.s('download_wizard_slot_free_space')} ${card['freeSpace']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              GlassPanel(
                active: true,
                onTap: processing || widget.controller.busy
                    ? null
                    : () async {
                        final value = await openPage<String>(
                          context,
                          const ScannerPage(),
                        );
                        if (value != null && mounted) await _parse(value);
                      },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: flowPurple.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: flowPurple,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.s('ui_scan'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.s('download_wizard_method_qr_code'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                onTap: processing || widget.controller.busy ? null : _image,
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 30),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        context.s('ui_image'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                minLines: 1,
                maxLines: 4,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.s('profile_download_code'),
                  hintText: 'LPA:1\$…',
                  suffixIcon: IconButton(
                    tooltip: context.s('download_wizard_method_clipboard'),
                    icon: const Icon(Icons.content_paste_go_outlined),
                    onPressed: () async {
                      final clipboard = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (!mounted) return;
                      if (clipboard?.text?.isNotEmpty == true) {
                        code.text = clipboard!.text!;
                        await _parse(code.text);
                      } else {
                        widget.controller.showMessage?.call(
                          'profile_download_no_lpa_string',
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: processing || widget.controller.busy
                      ? null
                      : () => openPage(
                          context,
                          DownloadDetailsPage(controller: widget.controller),
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.s('ui_manual')),
                ),
              ),
              const SizedBox(height: 30),
              FlowButton(
                label: context.s('ui_continue'),
                onPressed: processing || widget.controller.busy
                    ? null
                    : () => _parse(code.text.trim()),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class DownloadDetailsPage extends StatefulWidget {
  const DownloadDetailsPage({
    super.key,
    required this.controller,
    this.details = const {},
  });
  final EuiccController controller;
  final Json details;
  @override
  State<DownloadDetailsPage> createState() => _DownloadDetailsPageState();
}

class _DownloadDetailsPageState extends State<DownloadDetailsPage> {
  final form = GlobalKey<FormState>();
  late final address = TextEditingController(
    text: widget.details['address'] as String?,
  );
  late final matching = TextEditingController(
    text: widget.details['matchingId'] as String?,
  );
  final confirmation = TextEditingController(), imei = TextEditingController();
  bool submitting = false;
  @override
  void dispose() {
    address.dispose();
    matching.dispose();
    confirmation.dispose();
    imei.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (!form.currentState!.validate() ||
        submitting ||
        widget.controller.busy) {
      return;
    }
    setState(() => submitting = true);
    try {
      final lowBattery = await widget.controller.invoke<bool>('lowBattery');
      if (!mounted) return;
      if (lowBattery == true &&
          !await confirmAction(
            context,
            context.s('download_wizard_low_power'),
            context.s('download_wizard_low_power_content'),
          )) {
        return;
      }
      if (!mounted) return;
      await widget.controller.startTask('download', {
        'address': address.text,
        'matchingId': matching.text,
        'confirmationCode': confirmation.text,
        'imei': imei.text,
      });
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => DownloadProgressPage(controller: widget.controller),
          ),
        );
      }
    } on PlatformException catch (e) {
      widget.controller.showMessage?.call(e.code);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('home_add_profile'),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.controller.selected?['title'] ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(context.s('download_wizard_details')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: address,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: context.s('profile_download_server'),
            ),
            validator: (value) => value?.trim().contains('.') == true
                ? null
                : context.s('invalid_address'),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: matching,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: context.s('profile_download_code'),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: confirmation,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: context.s(
                widget.details['confirmationRequired'] == true
                    ? 'profile_download_confirmation_code_required'
                    : 'profile_download_confirmation_code',
              ),
            ),
            validator: (value) =>
                widget.details['confirmationRequired'] == true &&
                    (value?.trim().isEmpty ?? true)
                ? context.s('profile_download_confirmation_code_required')
                : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: imei,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.s('profile_download_imei'),
            ),
          ),
          const SizedBox(height: 30),
          FlowButton(
            label: context.s('ui_continue'),
            onPressed: submitting ? null : _download,
          ),
        ],
      ),
    ),
  );
}

class DownloadProgressPage extends StatefulWidget {
  const DownloadProgressPage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<DownloadProgressPage> createState() => _DownloadProgressPageState();
}

class _DownloadProgressPageState extends State<DownloadProgressPage> {
  bool confirming = false;
  final Set<int> confirmed = {};
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final task = widget.controller.task;
    final id = task?['id'] as int?;
    if (task?['metadata'] != null &&
        id != null &&
        !confirmed.contains(id) &&
        !confirming) {
      confirming = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _confirm(id, json(task!['metadata'])),
      );
    }
  }

  Future<void> _confirm(int id, Json metadata) async {
    if (!mounted) return;
    final accepted =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialog) => AlertDialog(
            scrollable: true,
            title: Text(context.s('ui_confirm_download')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata.isNotEmpty) ...[
                  Text(
                    '${metadata['name'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('${metadata['provider'] ?? ''}'),
                  const SizedBox(height: 12),
                  SelectableText('ICCID: ${metadata['iccid'] ?? ''}'),
                ],
                const SizedBox(height: 12),
                Text(context.s('deep_link_confirmation_dialog_description')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(context.s('ui_cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(context.s('ui_continue')),
              ),
            ],
          ),
        ) ??
        false;
    confirmed.add(id);
    confirming = false;
    await widget.controller.guard(() async {
      await widget.controller.invoke('confirm', {
        'id': id,
        'accepted': accepted,
      });
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final task = widget.controller.task ?? {};
      final busy = task['running'] == true;
      final failed = task['error'] != null;
      const phases = [
        'Preparing',
        'Connecting',
        'Authenticating',
        'Downloading',
        'Finalizing',
      ];
      final phase = task['phase'] == 'ConfirmingDownload'
          ? 2
          : phases.indexOf('${task['phase']}');
      const titles = [
        'preparing',
        'connecting',
        'authenticating',
        'downloading',
        'finalizing',
      ];
      return FlowPage(
        title: context.s('home_add_profile'),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GlassPanel(
              active: true,
              child: Column(
                children: [
                  if (busy)
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CircularProgressIndicator(
                        value: (task['progress'] as num? ?? 0) > 0
                            ? (task['progress'] as num) / 100
                            : null,
                        strokeWidth: 5,
                      ),
                    )
                  else
                    Icon(
                      failed ? Icons.error_outline : Icons.check_circle_outline,
                      size: 74,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    context.s(
                      busy
                          ? 'download_wizard_progress'
                          : failed
                          ? '${task['error']}'
                          : 'ui_download_complete',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (task['message'] != null) ...[
                    const SizedBox(height: 16),
                    Text('${task['message']}', textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < titles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        !busy && !failed || i < phase
                            ? Icons.check_circle_outline
                            : i == phase
                            ? failed
                                  ? Icons.error_outline
                                  : Icons.timelapse
                            : Icons.circle_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          context.s(
                            'download_wizard_progress_step_${titles[i]}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (task['diagnostics'] != null) ...[
              const SizedBox(height: 20),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.s('download_wizard_diagnostics'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${task['diagnostics']}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.controller.guard(() async {
                        await widget.controller.invoke('export', {
                          'text': task['diagnostics'],
                        });
                      }),
                      icon: const Icon(Icons.save_alt),
                      label: Text(context.s('ui_save')),
                    ),
                  ],
                ),
              ),
            ],
            if (!busy) ...[
              const SizedBox(height: 24),
              FlowButton(
                label: context.s('ui_done'),
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final camera = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    autoStart: false,
  );
  bool returned = false;

  Future<void> _start() async {
    try {
      await camera.start();
    } on MobileScannerException {
      // MobileScanner renders the permission and camera error state.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && !returned) {
      unawaited(_start());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FlowPage(
    title: context.s('ui_scan'),
    actions: [
      IconButton(
        tooltip: context.s('ui_scan'),
        onPressed: camera.toggleTorch,
        icon: const Icon(Icons.flash_on_outlined),
      ),
    ],
    body: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: MobileScanner(
        controller: camera,
        onDetect: (capture) {
          final value = capture.barcodes
              .map((barcode) => barcode.rawValue)
              .whereType<String>()
              .firstOrNull;
          if (value != null && !returned) {
            returned = true;
            unawaited(camera.stop());
            Navigator.pop(context, value);
          }
        },
        errorBuilder: (context, error) => StatePanel(
          title: context.s('operation_failed'),
          subtitle: context.s('download_wizard_method_gallery'),
          action: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.s('ui_cancel')),
          ),
        ),
        overlayBuilder: (context, constraints) => Center(
          child: IgnorePointer(
            child: Container(
              width: constraints.maxWidth * .7,
              height: constraints.maxWidth * .7,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: .8),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
