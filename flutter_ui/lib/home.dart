import 'package:flutter/material.dart';

import 'controller.dart';
import 'design.dart';
import 'download.dart';
import 'strings.dart';
import 'tools_pages.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});
  final EuiccController controller;

  Future<void> _action(
    BuildContext context,
    Json profile,
    String action,
  ) async {
    await controller.guard(() async {
      final name = '${profile['name']}';
      if (action == 'rename') {
        final value = await editValue(
          context,
          context.s('profile_rename'),
          value: name,
          hint: context.s('profile_rename_new_name'),
        );
        if (value != null) {
          await controller.startTask('rename', {
            'iccid': profile['iccid'],
            'name': value,
          });
        }
      } else if (action == 'delete') {
        final value = await editValue(
          context,
          context.s('profile_delete'),
          message: context.s('profile_delete_confirm', [name]),
          hint: context.s('profile_delete_confirm_input', [name]),
          mustMatch: name,
        );
        if (value != null) {
          await controller.startTask('delete', {
            'iccid': profile['iccid'],
            'confirmation': value,
          });
        }
      } else {
        await controller.startTask('switch', {
          'iccid': profile['iccid'],
          'enable': action == 'enable',
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = controller.selected;
    final locked = controller.busy || controller.scanning || controller.reading;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AppBar(
          title: const Text(
            'FluxEUICC',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: context.s('profile_reload_slots'),
              onPressed: locked ? null : controller.reload,
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              tooltip: context.s('menu_actions'),
              enabled: !locked,
              onSelected: (value) {
                switch (value) {
                  case 'compatibility':
                    openPage(
                      context,
                      CompatibilityPage(controller: controller),
                    );
                  case 'info':
                    openPage(context, InfoPage(controller: controller));
                  case 'notifications':
                    openPage(
                      context,
                      NotificationsPage(controller: controller),
                    );
                  case 'toolkit':
                    controller.guard(() async {
                      await controller.invoke('toolkit', {
                        'slot': card!['slot'],
                      });
                    });
                  case 'reset':
                    _reset(context);
                }
              },
              itemBuilder: (_) => [
                if (card != null) ...[
                  PopupMenuItem(
                    value: 'info',
                    child: Text(context.s('euicc_info')),
                  ),
                  PopupMenuItem(
                    value: 'notifications',
                    child: Text(context.s('profile_notifications_show')),
                  ),
                  if (card['toolkit'] == true)
                    PopupMenuItem(
                      value: 'toolkit',
                      child: Text(context.s('open_sim_toolkit')),
                    ),
                  if (card['usb'] == true ||
                      controller.preferences['disableSafeguard'] == true)
                    PopupMenuItem(
                      value: 'reset',
                      child: Text(
                        context.s('euicc_memory_reset'),
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  const PopupMenuDivider(),
                ],
                PopupMenuItem(
                  value: 'compatibility',
                  child: Text(context.s('compatibility_check')),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.readProfiles,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                Text(
                  context.s('home_eyebrow'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 24),
                BusyBanner(
                  controller: controller,
                  onTap: controller.task?['kind'] == 'download'
                      ? () => openPage(
                          context,
                          DownloadProgressPage(controller: controller),
                        )
                      : null,
                ),
                if (controller.scanning || controller.reading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 18),
                ],
                if (card != null) ...[
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const SimGlyph(size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: PopupMenuButton<int>(
                            enabled: !locked,
                            tooltip: context.s('download_wizard_slot_select'),
                            onSelected: (index) =>
                                controller.select(controller.cards[index]),
                            itemBuilder: (_) => [
                              for (var i = 0; i < controller.cards.length; i++)
                                PopupMenuItem(
                                  value: i,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${controller.cards[i]['title']}',
                                    ),
                                    subtitle: Text(
                                      '${controller.cards[i]['active'] ?? context.s('no_profile')}',
                                    ),
                                    trailing:
                                        EuiccController.sameCard(
                                          controller.cards[i],
                                          card,
                                        )
                                        ? const Icon(Icons.check)
                                        : null,
                                  ),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${card['title']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (controller.error != null)
                  StatePanel(
                    title: context.s(controller.error!),
                    icon: Icons.warning_amber_rounded,
                    action: TextButton.icon(
                      onPressed: controller.reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.s('ui_retry')),
                    ),
                  ),
                if (controller.usb != null &&
                    controller.usb!['opened'] != true) ...[
                  const SizedBox(height: 16),
                  StatePanel(
                    title: '${controller.usb!['name']}',
                    subtitle: context.s(
                      controller.usb!['permission'] == true
                          ? 'usb_failed'
                          : 'usb_permission_needed',
                    ),
                    icon: Icons.usb,
                    action: TextButton(
                      onPressed: () => controller.guard(() async {
                        if (controller.usb!['permission'] != true) {
                          await controller.invoke('usbPermission');
                        }
                        await controller.reload();
                      }),
                      child: Text(
                        context.s(
                          controller.usb!['permission'] == true
                              ? 'ui_retry'
                              : 'usb_permission',
                        ),
                      ),
                    ),
                  ),
                ],
                if (card == null &&
                    !controller.scanning &&
                    controller.error == null)
                  StatePanel(
                    title: context.s('empty_heading'),
                    subtitle: context.s('empty_hint'),
                    action: TextButton(
                      onPressed: () => openPage(
                        context,
                        CompatibilityPage(controller: controller),
                      ),
                      child: Text(context.s('compatibility_check')),
                    ),
                  ),
                if (card != null &&
                    controller.profiles.isEmpty &&
                    !locked &&
                    controller.error == null)
                  StatePanel(
                    title: context.s('empty_profiles_heading'),
                    subtitle: context.s('empty_profiles_hint'),
                  ),
                for (final profile in controller.profiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ProfileCard(
                      profile: profile,
                      locked: locked || controller.error != null,
                      onAction: (action) => _action(context, profile, action),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: FlowButton(
            label: context.s('home_add_profile'),
            icon: Icons.add,
            onPressed: card == null || locked || controller.error != null
                ? null
                : () => openPage(context, DownloadPage(controller: controller)),
          ),
        ),
      ],
    );
  }

  Future<void> _reset(BuildContext context) => controller.guard(() async {
    final eid = '${controller.selected!['eid']}';
    final match = context.s('euicc_memory_reset_confirm_text', [
      eid.substring(eid.length > 8 ? eid.length - 8 : 0),
    ]);
    final value = await editValue(
      context,
      context.s('euicc_memory_reset_title'),
      message: context.s('euicc_memory_reset_message', [eid, match]),
      hint: context.s('euicc_memory_reset_hint_text', [match]),
      mustMatch: match,
    );
    if (value != null) {
      await controller.startTask('reset', {'confirmation': value});
    }
  });
}

class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    required this.locked,
    required this.onAction,
  });
  final Json profile;
  final bool locked;
  final ValueChanged<String> onAction;
  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool reveal = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final active = p['enabled'] == true;
    final colors = Theme.of(context).colorScheme;
    return GlassPanel(
      active: active,
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active)
            Container(
              width: 4,
              height: 165,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [flowPurple, flowBlue],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SimGlyph(active: active),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['name']}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${p['provider']}',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !widget.locked,
                        tooltip: context.s('profile_actions'),
                        onSelected: widget.onAction,
                        itemBuilder: (_) => [
                          if (!active)
                            PopupMenuItem(
                              value: 'enable',
                              enabled: p['canEnable'] == true,
                              child: Text(context.s('profile_enable')),
                            ),
                          if (active && p['canDisable'] == true)
                            PopupMenuItem(
                              value: 'disable',
                              child: Text(context.s('profile_disable')),
                            ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(context.s('profile_rename')),
                          ),
                          if (!active)
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                context.s('profile_delete'),
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (active ? colors.primary : colors.onSurfaceVariant)
                          .withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      context.s(
                        active
                            ? 'profile_state_enabled'
                            : 'profile_state_disabled',
                      ),
                      style: TextStyle(
                        color: active
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (p['showClass'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        context.s(
                          'profile_class_${'${p['class']}'.toLowerCase()}',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => reveal = !reveal),
                    onLongPress: () => copyValue(
                      context,
                      '${p['iccid']}',
                      'toast_iccid_copied',
                    ),
                    child: Semantics(
                      button: true,
                      label: 'ICCID',
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ICCID  ${reveal ? p['iccid'] : '•••• •••• •••• ••••'}',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(
                            reveal
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
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
