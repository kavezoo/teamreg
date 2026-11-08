/*
 * Beszélgetések.
 *
 * A flash koppintása ide nyit, ha az üzenethez beszélgetés tartozik.
 * A válasz a másik fél telefonjára flashként megy ki.
 */
import 'dart:async';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../state/app_model.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
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
                  if (_error == null && _desk?.notice != null) ...[
                    const SizedBox(height: 16),
                    Text(_desk!.notice!),
                  ],
                  if (_error == null && _desk?.notice == null && threads.isEmpty) ...[
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

/// Új üzenet mindenkinek, vagy a kijelölt tagoknak.
class MessageComposePage extends StatefulWidget {
  const MessageComposePage({super.key});

  @override
  State<MessageComposePage> createState() => _MessageComposePageState();
}

class _MessageComposePageState extends State<MessageComposePage> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  List<MessagePeer> _recipients = const [];
  final Set<String> _selected = {};
  bool _everyone = false;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
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
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final fallback = _loadedMembers();
      setState(() {
        _recipients = fallback;
        _error = fallback.isEmpty ? friendlyError(error) : null;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// A kezdőlapon már meglévő tagok, ha az üzenetkérés nem ad címzetteket.
  List<MessagePeer> _loadedMembers() {
    final model = AppScope.of(context);
    final self = model.user;
    final byId = <String, MessagePeer>{};
    for (final member in model.data?.members?.members ?? const <ClubMember>[]) {
      if (member.id.isNotEmpty) {
        byId[member.id] = MessagePeer(id: member.id, name: member.name, role: member.role);
      }
    }
    for (final row in model.data?.registrations ?? const <Registration>[]) {
      if (row.userId.isNotEmpty) {
        byId.putIfAbsent(
          row.userId,
          () => MessagePeer(id: row.userId, name: row.userName, role: 'member'),
        );
      }
    }
    for (final row in model.data?.roster ?? const <RosterLine>[]) {
      if (row.userId.isNotEmpty && row.name.isNotEmpty) {
        byId.putIfAbsent(row.userId, () => MessagePeer(id: row.userId, name: row.name, role: 'member'));
      }
    }
    // Tesztelés: saját fiók is címzett. Később ez a blokk kivehető.
    if (self != null && self.id.isNotEmpty) {
      byId.putIfAbsent(
        self.id,
        () => MessagePeer(
          id: self.id,
          name: self.name.isEmpty ? self.email : self.name,
          role: self.role,
        ),
      );
    }
    final people = byId.values.toList();
    return _sorted(people);
  }

  List<MessagePeer> _sorted(List<MessagePeer> people) {
    final self = AppScope.of(context).user?.id;
    people.sort((a, b) {
      if (a.id == self) {
        return -1;
      }
      if (b.id == self) {
        return 1;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return people;
  }

  String _peerLabel(MessagePeer person) {
    if (person.id == AppScope.of(context).user?.id) {
      return '${person.label} (én)';
    }
    return person.label;
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (!_everyone && _selected.isEmpty) {
      showMessage(context, 'Válassz legalább egy tagot, vagy küldd mindenkinek.');
      return;
    }
    if (subject.isEmpty || body.isEmpty) {
      showMessage(context, 'A cím és az üzenet is kell.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).sendClubMessage(
        everyone: _everyone,
        recipientIds: _selected.toList(),
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

  /// A szerver listája és a már betöltött tagok együtt. A kezdőlap később is bővítheti.
  List<MessagePeer> _people() {
    final byId = <String, MessagePeer>{};
    for (final person in _recipients) {
      if (person.id.isNotEmpty) {
        byId[person.id] = person;
      }
    }
    for (final person in _loadedMembers()) {
      byId.putIfAbsent(person.id, () => person);
    }
    return _sorted(byId.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final people = _people();
    final canSend = !_busy && (_everyone || _selected.isNotEmpty);
    return ClubScaffold(
      title: 'Új üzenet',
      showFlash: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                RadioGroup<bool>(
                  groupValue: _everyone,
                  onChanged: (value) => setState(() => _everyone = value ?? false),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Mindenkinek'),
                        value: true,
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Kiválasztott tagok'),
                        value: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null && people.isEmpty) Text(_error!),
                if (people.isEmpty && _error == null) const Text('Nincs választható tag.'),
                if (_everyone)
                  for (final person in people)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_peerLabel(person)),
                    )
                else
                  for (final person in people)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(person.id),
                      title: Text(_peerLabel(person)),
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            _selected.add(person.id);
                          } else {
                            _selected.remove(person.id);
                          }
                        });
                      },
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
                  onPressed: canSend ? _send : null,
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

class _MessageThreadPageState extends State<MessageThreadPage> with WidgetsBindingObserver {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  MessageThread? _thread;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _refreshing = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _load();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _reply.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!mounted || _loading || _refreshing) {
      return;
    }
    await _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    if (quiet) {
      _refreshing = true;
    }
    try {
      final model = AppScope.of(context);
      final threadFuture = model.messageThread(widget.threadId);
      if (quiet) {
        await model.refreshFlashes();
      }
      final thread = await threadFuture;
      if (!mounted) {
        return;
      }
      final previous = _thread;
      final changed = !_samePosts(previous, thread);
      if (!quiet || changed || _error != null) {
        setState(() {
          _thread = thread;
          _error = null;
        });
      }
      if (changed) {
        _scrollToEnd();
        await _markThreadFlashesSeen(model);
      } else if (quiet) {
        await _markThreadFlashesSeen(model);
      }
    } catch (error) {
      if (mounted && !quiet) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      _refreshing = false;
      if (mounted && !quiet) {
        setState(() => _loading = false);
      }
    }
  }

  bool _samePosts(MessageThread? previous, MessageThread next) {
    if (previous == null) {
      return false;
    }
    if (previous.posts.length != next.posts.length) {
      return false;
    }
    for (var index = 0; index < next.posts.length; index++) {
      if (previous.posts[index].id != next.posts[index].id) {
        return false;
      }
    }
    return true;
  }

  Future<void> _markThreadFlashesSeen(AppModel model) async {
    final unread = model.flashes
        .where(
          (flash) =>
              flash.unread && flash.target == 'message' && flash.targetId == widget.threadId,
        )
        .toList();
    for (final flash in unread) {
      await model.markFlashSeen(flash.id);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty || _busy) {
      return;
    }
    final model = AppScope.of(context);
    final user = model.user;
    final pending = MessagePost(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: user?.id ?? '',
      senderName: user?.name ?? 'Én',
      senderAvatar: model.ownPhoto,
      body: body,
      mine: true,
      created: '',
      when: DateTime.now(),
    );
    setState(() {
      _busy = true;
      _reply.clear();
      final current = _thread;
      if (current != null) {
        _thread = MessageThread(
          id: current.id,
          subject: current.subject,
          peerName: current.peerName,
          peerAvatar: current.peerAvatar,
          posts: [...current.posts, pending],
        );
      }
    });
    _scrollToEnd();
    try {
      await model.replyClubMessage(widget.threadId, body);
      await _load(quiet: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          final current = _thread;
          if (current != null) {
            _thread = MessageThread(
              id: current.id,
              subject: current.subject,
              peerName: current.peerName,
              peerAvatar: current.peerAvatar,
              posts: current.posts.where((post) => post.id != pending.id).toList(),
            );
          }
        });
        showMessage(context, friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  List<Widget> _chatItems(MessageThread thread) {
    final model = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final bubbleMax = width - 96;
    final items = <Widget>[];
    DateTime? previousDay;
    for (final post in thread.posts) {
      final when = post.when;
      if (when != null) {
        final day = DateTime(when.year, when.month, when.day);
        if (previousDay != day) {
          previousDay = day;
          items.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  formatChatDay(when),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }
      }
      final avatarUrl = post.senderAvatar ?? model.avatarFor(post.senderId) ?? (post.mine ? model.ownPhoto : null);
      final fill = post.mine
          ? scheme.primary.withValues(alpha: scheme.brightness == Brightness.dark ? 0.28 : 0.14)
          : scheme.surface;
      final border = scheme.outlineVariant;
      final bubble = Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bubbleMax),
          child: _SpeechBubble(
            mine: post.mine,
            fill: fill,
            border: border,
            child: Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      );
      final avatar = UserAvatar(name: post.senderName, url: avatarUrl, radius: 16);
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: post.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: post.mine
                ? [bubble, const SizedBox(width: 6), avatar]
                : [avatar, const SizedBox(width: 6), bubble],
          ),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    final scheme = Theme.of(context).colorScheme;
    final partner = thread?.peerName.trim() ?? '';
    return ClubScaffold(
      title: partner.isEmpty ? 'Üzenet' : partner,
      showFlash: false,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!),
                        ),
                      if (thread != null) ..._chatItems(thread),
                    ],
                  ),
                ),
                if (thread != null)
                  SafeArea(
                    top: false,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        border: Border(
                          top: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 2, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _reply,
                                focusNode: _focus,
                                minLines: 1,
                                maxLines: 6,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Üzenet',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.fromLTRB(12, 10, 8, 10),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Küldés',
                              onPressed: _busy ? null : _send,
                              style: IconButton.styleFrom(
                                foregroundColor: scheme.primary,
                                padding: const EdgeInsets.all(10),
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: _busy
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.send, size: 26),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Keretes buborék, a profilkép felé mutató kis háromszög nyíllal.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.mine,
    required this.fill,
    required this.border,
    required this.child,
  });

  final bool mine;
  final Color fill;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeechBubblePainter(mine: mine, fill: fill, border: border),
      child: Padding(
        padding: EdgeInsets.fromLTRB(mine ? 12 : 18, 10, mine ? 18 : 12, 10),
        child: child,
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  _SpeechBubblePainter({required this.mine, required this.fill, required this.border});

  final bool mine;
  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 14.0;
    const tip = 8.0;
    final body = RRect.fromLTRBR(
      mine ? 0 : tip,
      0,
      mine ? size.width - tip : size.width,
      size.height,
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(body);
    // A nyíl a felső profilkép felé mutat.
    const tipY = 16.0;
    if (mine) {
      path.moveTo(size.width - tip, tipY - 7);
      path.lineTo(size.width, tipY);
      path.lineTo(size.width - tip, tipY + 7);
    } else {
      path.moveTo(tip, tipY - 7);
      path.lineTo(0, tipY);
      path.lineTo(tip, tipY + 7);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.mine != mine || oldDelegate.fill != fill || oldDelegate.border != border;
  }
}
