import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'controller.dart';
import 'design.dart';
import 'strings.dart';

Future<void> _showDownloadDetails(
  BuildContext context,
  EuiccController controller,
  String input,
) => controller.guard(() async {
  final parsed = json(await controller.invoke('parse', {'input': input}));
  if (context.mounted) {
    await openPage(
      context,
      DownloadDetailsPage(controller: controller, details: parsed),
    );
  }
});

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key, required this.controller, this.lpa});
  final EuiccController controller;
  final String? lpa;
  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  bool processing = false;
  @override
  void initState() {
    super.initState();
    if (widget.lpa != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _parse(widget.lpa!);
      });
    }
  }

  Future<void> _parse(String input) async {
    if (processing) return;
    setState(() => processing = true);
    await _showDownloadDetails(context, widget.controller, input);
    if (mounted) setState(() => processing = false);
  }

  Future<void> _scan() async {
    final value = await openPage<String>(context, const ScannerPage());
    if (value != null && mounted) await _parse(value);
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
      final locked =
          processing ||
          widget.controller.busy ||
          widget.controller.scanning ||
          widget.controller.reading;
      return FlowPage(
        title: context.s('home_add_profile'),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.controller.cards.length > 1 && card != null) ...[
              CardSelector(controller: widget.controller, enabled: !locked),
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
              DownloadMethodCard(
                icon: Icons.qr_code_scanner_rounded,
                title: context.s('ui_scan'),
                subtitle: context.s('download_wizard_method_qr_code'),
                active: true,
                onTap: locked ? null : _scan,
              ),
              const SizedBox(height: 16),
              DownloadMethodCard(
                icon: Icons.image_outlined,
                title: context.s('ui_image'),
                subtitle: context.s('download_wizard_method_gallery'),
                onTap: locked ? null : _image,
              ),
              const SizedBox(height: 16),
              DownloadMethodCard(
                key: const Key('activation-code-option'),
                icon: Icons.content_paste_go_outlined,
                title: context.s('profile_download_code'),
                subtitle: context.s('ui_code_hint'),
                onTap: locked
                    ? null
                    : () => openPage(
                        context,
                        ActivationCodePage(controller: widget.controller),
                      ),
              ),
              const SizedBox(height: 16),
              DownloadMethodCard(
                key: const Key('manual-input-option'),
                icon: Icons.edit_outlined,
                title: context.s('ui_manual'),
                subtitle: context.s('ui_manual_hint'),
                onTap: locked
                    ? null
                    : () => openPage(
                        context,
                        DownloadDetailsPage(controller: widget.controller),
                      ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class DownloadMethodCard extends StatelessWidget {
  const DownloadMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassPanel(
      active: active,
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: colors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: colors.primary),
        ],
      ),
    );
  }
}

class ActivationCodePage extends StatefulWidget {
  const ActivationCodePage({super.key, required this.controller});
  final EuiccController controller;
  @override
  State<ActivationCodePage> createState() => _ActivationCodePageState();
}

class _ActivationCodePageState extends State<ActivationCodePage> {
  final code = TextEditingController();
  final form = GlobalKey<FormState>();
  bool processing = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (processing ||
        widget.controller.busy ||
        !form.currentState!.validate()) {
      return;
    }
    setState(() => processing = true);
    await _showDownloadDetails(context, widget.controller, code.text.trim());
    if (mounted) setState(() => processing = false);
  }

  Future<void> _paste() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (clipboard?.text?.trim().isNotEmpty == true) {
      code.text = clipboard!.text!.trim();
      await _submit();
    } else {
      widget.controller.showMessage?.call('profile_download_no_lpa_string');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => FlowPage(
      title: context.s('profile_download_code'),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GlassPanel(
              child: Text(
                context.s('ui_code_hint'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: code,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !processing && !widget.controller.busy,
              decoration: InputDecoration(
                labelText: context.s('profile_download_code'),
                hintText: 'LPA:1\$…',
              ),
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : context.s('profile_download_no_lpa_string'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: processing || widget.controller.busy ? null : _paste,
                icon: const Icon(Icons.content_paste_go_outlined),
                label: Text(context.s('download_wizard_method_clipboard')),
              ),
            ),
            const SizedBox(height: 24),
            FlowButton(
              label: context.s('ui_continue'),
              onPressed: processing || widget.controller.busy ? null : _submit,
            ),
          ],
        ),
      ),
    ),
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
