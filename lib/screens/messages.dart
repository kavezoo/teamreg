/*
 * Beszélgetések.
 *
 * A flash koppintása ide nyit, ha az üzenethez beszélgetés tartozik.
 * A válasz a másik fél telefonjára flashként megy ki.
 */
import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';

/// A saját beszélgetések listája.
class MessageDeskPage extends StatefulWidget {
  const MessageDeskPage({super.key});

  @override
  State<MessageDeskPage> createState() => _MessageDeskPageState();
}

class _MessageDeskPageState extends State<MessageDeskPage> {
  MessageDesk? _desk;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final desk = await AppScope.of(context).messageDesk();
      if (!mounted) {
        return;
      }
      setState(() => _desk = desk);
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final threads = _desk?.threads ?? const <MessagePreview>[];
    return ClubScaffold(
      title: 'Beszélgetések',
      showFlash: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  FilledButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (context) => const MessageComposePage()),
                      );
                      if (mounted) {
                        await _load();
                      }
                    },
                    child: const Text('Új üzenet'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!),
                  ],
                  if (_error == null && threads.isEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Még nincs beszélgetés.'),
                  ],
                  for (var index = 0; index < threads.length; index++)
                    Band(
                      index: index,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(threads[index].subject),
                        subtitle: Text('${threads[index].peerName}\n${threads[index].lastBody}'),
                        isThreeLine: true,
                        trailing: Text(threads[index].lastAt, style: Theme.of(context).textTheme.bodySmall),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => MessageThreadPage(threadId: threads[index].id),
                            ),
                          );
                          if (mounted) {
                            await _load();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Új üzenet egy kiválasztott tagnak vagy elnöknek.
class MessageComposePage extends StatefulWidget {
  const MessageComposePage({super.key});

  @override
  State<MessageComposePage> createState() => _MessageComposePageState();
}

class _MessageComposePageState extends State<MessageComposePage> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  List<MessagePeer> _recipients = const [];
  String? _recipientId;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final desk = await AppScope.of(context).messageDesk();
      if (!mounted) {
        return;
      }
      setState(() {
        _recipients = desk.recipients;
        _recipientId = desk.recipients.isEmpty ? null : desk.recipients.first.id;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final recipientId = _recipientId;
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (recipientId == null || recipientId.isEmpty) {
      showMessage(context, 'Válassz címzettet.');
      return;
    }
    if (subject.isEmpty || body.isEmpty) {
      showMessage(context, 'A cím és az üzenet is kell.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).sendClubMessage(
        recipientId: recipientId,
        subject: subject,
        body: body,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      showMessage(context, 'Az üzenet elment.');
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubScaffold(
      title: 'Új üzenet',
      showFlash: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_error != null) Text(_error!),
                if (_recipients.isEmpty && _error == null) const Text('Nincs választható címzett.'),
                if (_recipients.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _recipientId,
                    decoration: const InputDecoration(labelText: 'Címzett'),
                    items: [
                      for (final person in _recipients)
                        DropdownMenuItem(value: person.id, child: Text(person.label)),
                    ],
                    onChanged: (value) => setState(() => _recipientId = value),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Cím'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  decoration: const InputDecoration(labelText: 'Üzenet'),
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || _recipients.isEmpty ? null : _send,
                  child: Text(_busy ? 'Küldés…' : 'Üzenet küldése'),
                ),
              ],
            ),
    );
  }
}

/// Egy beszélgetés. A válasz flashként megy a másik félnek.
class MessageThreadPage extends StatefulWidget {
  const MessageThreadPage({required this.threadId, super.key});

  final String threadId;

  @override
  State<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends State<MessageThreadPage> {
  final _reply = TextEditingController();
  MessageThread? _thread;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await AppScope.of(context).messageThread(widget.threadId);
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = thread;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) {
      showMessage(context, 'A válasz szövege kell.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).replyClubMessage(widget.threadId, body);
      _reply.clear();
      await _load();
      if (mounted) {
        showMessage(context, 'A válasz elment.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    return ClubScaffold(
      title: thread?.subject.isNotEmpty == true ? thread!.subject : 'Üzenet',
      showFlash: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      if (thread != null) Text('Vele: ${thread.peerName}'),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!),
                      ],
                      if (thread != null)
                        for (final post in thread.posts) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: post.mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(post.senderName, style: Theme.of(context).textTheme.labelMedium),
                                      const SizedBox(height: 4),
                                      Text(post.body),
                                      const SizedBox(height: 4),
                                      Text(post.created, style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                if (thread != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _reply,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(labelText: 'Válasz'),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _busy ? null : _send,
                            child: Text(_busy ? '…' : 'Válasz'),
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
