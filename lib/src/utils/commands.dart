/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import '../../famedlysdk.dart';

class Commands {
  final Room room;
  final Map<String, FutureOr<String> Function(CommandArgs)> commands = {};

  Commands({this.room});

  void addCommand(String command, FutureOr<String> Function(CommandArgs) callback) {
    commands[command.toLowerCase()] = callback;
  }

  Future<String> parseAndRun(String msg, {Event inReplyTo, String editEventId}) async {
    final args = CommandArgs(
      inReplyTo: inReplyTo,
      editEventId: editEventId,
      msg: '',
    );
    if (!msg.startsWith('/')) {
      if (commands.containsKey('send')) {
        args.msg = msg;
        return await commands['send'](args);
      }
      return null;
    }
    // remove the /
    msg = msg.substring(1);
    var command = msg;
    if (msg.contains(' ')) {
      final idx = msg.indexOf(' ');
      command = msg.substring(0, idx).toLowerCase();
      args.msg = msg.substring(idx + 1);
    } else {
      command = msg.toLowerCase();
    }
    if (commands.containsKey(command)) {
      return await commands[command](args);
    }
    if (args.msg.startsWith('/') && commands.containsKey('send')) {
      // remove the second starting /
      args.msg = msg.substring(1);
      return await commands['send'](args);
    }
    return null;
  }

  void unregisterAllCommands() {
    commands.clear();
  }

  void registerRoomCommands() {
    addCommand('send', (CommandArgs args) async {
      return await room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
      );
    });
    addCommand('me', (CommandArgs args) async {
      return await room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        msgtype: 'm.emote',
      );
    });
    addCommand('plain', (CommandArgs args) async {
      return await room.sendTextEvent(
        args.msg,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
        parseMarkdown: false,
      );
    });
    addCommand('html', (CommandArgs args) async {
      final event = <String, dynamic>{
        'msgtype': 'm.text',
        'body': args.msg,
        'format': 'org.matrix.custom.html',
        'formatted_body': args.msg,
      };
      return await room.sendEvent(
        event,
        inReplyTo: args.inReplyTo,
        editEventId: args.editEventId,
      );
    });
    addCommand('react', (CommandArgs args) async {
      if (args.inReplyTo == null) {
        return null;
      }
      return await room.sendReaction(args.inReplyTo.eventId, args.msg);
    });
    addCommand('join', (CommandArgs args) async {
      await room.client.joinRoomOrAlias(args.msg);
      return null;
    });
    addCommand('leave', (CommandArgs args) async {
      await room.leave();
      return '';
    });
    addCommand('op', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      if (parts.isEmpty) {
        return null;
      }
      var pl = 50;
      if (parts.length >= 2) {
        pl = int.tryParse(parts[1]);
      }
      final mxid = parts.first;
      return await room.setPower(mxid, pl);
    });
    addCommand('kick', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await room.kick(parts.first);
      return '';
    });
    addCommand('ban', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await room.ban(parts.first);
      return '';
    });
    addCommand('unban', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await room.unban(parts.first);
      return '';
    });
    addCommand('invite', (CommandArgs args) async {
      final parts = args.msg.split(' ');
      await room.invite(parts.first);
      return '';
    });
    addCommand('myroomnick', (CommandArgs args) async {
      final currentEventJson = room.getState(EventTypes.RoomMember, room.client.userID).content.copy();
      currentEventJson['displayname'] = args.msg;
      return await room.client.sendState(
        room.id,
        EventTypes.RoomMember,
        currentEventJson,
        room.client.userID,
      );
    });
    addCommand('myroomavatar', (CommandArgs args) async {
      final currentEventJson = room.getState(EventTypes.RoomMember, room.client.userID).content.copy();
      currentEventJson['avatar_url'] = args.msg;
      return await room.client.sendState(
        room.id,
        EventTypes.RoomMember,
        currentEventJson,
        room.client.userID,
      );
    });
  }
}

class CommandArgs {
  String msg;
  String editEventId;
  Event inReplyTo;
  CommandArgs({this.msg, this.editEventId, this.inReplyTo});
}
