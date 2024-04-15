import 'package:flutter/material.dart' hide Visibility;

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/pages/chat_access_settings/chat_access_settings_controller.dart';
import 'package:fluffychat/utils/fluffy_share.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';

class ChatAccessSettingsPageView extends StatelessWidget {
  final ChatAccessSettingsController controller;
  const ChatAccessSettingsPageView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final room = controller.room;
    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        title: Text(L10n.of(context)!.accessAndVisibility),
      ),
      body: MaxWidthBody(
        child: StreamBuilder<Object>(
          stream: room.onUpdate.stream,
          builder: (context, snapshot) {
            final canonicalAlias = room.canonicalAlias;
            final altAliases = room
                    .getState(EventTypes.RoomCanonicalAlias)
                    ?.content
                    .tryGetList<String>('alt_aliases') ??
                [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    L10n.of(context)!.visibilityOfTheChatHistory,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final historyVisibility in HistoryVisibility.values)
                  RadioListTile<HistoryVisibility>.adaptive(
                    title: Text(
                      historyVisibility
                          .getLocalizedString(MatrixLocals(L10n.of(context)!)),
                    ),
                    value: historyVisibility,
                    groupValue: room.historyVisibility,
                    onChanged: controller.historyVisibilityLoading ||
                            !room.canChangeHistoryVisibility
                        ? null
                        : controller.setHistoryVisibility,
                  ),
                Divider(color: Theme.of(context).dividerColor),
                ListTile(
                  title: Text(
                    L10n.of(context)!.whoIsAllowedToJoinThisGroup,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final joinRule in JoinRules.values)
                  if (joinRule != JoinRules.private)
                    RadioListTile<JoinRules>.adaptive(
                      title: Text(
                        joinRule.localizedString(L10n.of(context)!),
                      ),
                      value: joinRule,
                      groupValue: room.joinRules,
                      onChanged: controller.joinRulesLoading ||
                              !room.canChangeJoinRules
                          ? null
                          : controller.setJoinRule,
                    ),
                Divider(color: Theme.of(context).dividerColor),
                if ({JoinRules.public, JoinRules.knock}
                    .contains(room.joinRules)) ...[
                  ListTile(
                    title: Text(
                      L10n.of(context)!.areGuestsAllowedToJoin,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final guestAccess in GuestAccess.values)
                    RadioListTile<GuestAccess>.adaptive(
                      title: Text(
                        guestAccess.getLocalizedString(
                          MatrixLocals(L10n.of(context)!),
                        ),
                      ),
                      value: guestAccess,
                      groupValue: room.guestAccess,
                      onChanged: controller.guestAccessLoading ||
                              !room.canChangeGuestAccess
                          ? null
                          : controller.setGuestAccess,
                    ),
                  Divider(color: Theme.of(context).dividerColor),
                  ListTile(
                    title: Text(
                      L10n.of(context)!.publicLinks,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_outlined),
                      tooltip: L10n.of(context)!.createNewLink,
                      onPressed: controller.addAlias,
                    ),
                  ),
                  if (canonicalAlias.isNotEmpty)
                    _AliasListTile(
                      alias: canonicalAlias,
                      onDelete: room.canChangeStateEvent(
                        EventTypes.RoomCanonicalAlias,
                      )
                          ? () => controller.deleteAlias(canonicalAlias)
                          : null,
                      isCanonicalAlias: true,
                    ),
                  for (final alias in altAliases)
                    _AliasListTile(
                      alias: alias,
                      onDelete: room.canChangeStateEvent(
                        EventTypes.RoomCanonicalAlias,
                      )
                          ? () => controller.deleteAlias(alias)
                          : null,
                    ),
                  Divider(color: Theme.of(context).dividerColor),
                  FutureBuilder(
                    future: room.client.getRoomVisibilityOnDirectory(room.id),
                    builder: (context, snapshot) => SwitchListTile.adaptive(
                      value: snapshot.data == Visibility.public,
                      title: Text(
                        L10n.of(context)!.chatCanBeDiscoveredViaSearchOnServer(
                          room.client.userID!.domain!,
                        ),
                      ),
                      onChanged: controller.setChatVisibilityOnDirectory,
                    ),
                  ),
                ],
                ListTile(
                  title: Text(L10n.of(context)!.globalChatId),
                  subtitle: SelectableText(room.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => FluffyShare.share(room.id, context),
                  ),
                ),
                ListTile(
                  title: Text(L10n.of(context)!.roomVersion),
                  subtitle: SelectableText(
                    room
                            .getState(EventTypes.RoomCreate)!
                            .content
                            .tryGet<String>('room_version') ??
                        'Unknown',
                  ),
                  trailing: room.canSendEvent(EventTypes.RoomTombstone)
                      ? IconButton(
                          icon: const Icon(Icons.upgrade_outlined),
                          onPressed: controller.updateRoomAction,
                        )
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AliasListTile extends StatelessWidget {
  const _AliasListTile({
    required this.alias,
    required this.onDelete,
    this.isCanonicalAlias = false,
  });

  final String alias;
  final void Function()? onDelete;
  final bool isCanonicalAlias;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          TextButton.icon(
            onPressed: () => FluffyShare.share(
              'https://matrix.to/#/$alias',
              context,
            ),
            icon: isCanonicalAlias
                ? const Icon(Icons.star)
                : const Icon(Icons.link_outlined),
            label: SelectableText(
              'https://matrix.to/#/$alias',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outlined),
              onPressed: onDelete,
            )
          : null,
    );
  }
}

extension JoinRulesDisplayString on JoinRules {
  String localizedString(L10n l10n) {
    switch (this) {
      case JoinRules.public:
        return l10n.anyoneCanJoin;
      case JoinRules.invite:
        return l10n.invitedUsersOnly;
      case JoinRules.knock:
        return l10n.usersMustKnock;
      case JoinRules.private:
        return l10n.noOneCanJoin;
    }
  }
}
