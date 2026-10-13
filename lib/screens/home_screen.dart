import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/providers/draft_providers.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:np_pole_tag_stickerman/providers/search_providers.dart';
import 'package:np_pole_tag_stickerman/providers/sign_out.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/upload_providers.dart';
import 'package:np_pole_tag_stickerman/router/app_router.dart';
import 'package:np_pole_tag_stickerman/widgets/home/home_body.dart';
import 'package:np_pole_tag_stickerman/widgets/home/home_header.dart';
import 'package:np_pole_tag_stickerman/widgets/home/error_banner.dart';
import 'package:np_pole_tag_stickerman/widgets/home/refused_line.dart';
import 'package:np_pole_tag_stickerman/widgets/home/scan_button.dart';
import 'package:np_pole_tag_stickerman/widgets/home/search_box.dart';
import 'package:np_pole_tag_stickerman/widgets/home/search_results.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_tabs.dart';
import 'package:np_pole_tag_stickerman/widgets/home/waiting_line.dart';
import 'package:np_pole_tag_stickerman/widgets/home/awaiting_line.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tagProvider.notifier).loadMyTags();

      // Which rows say Draft. Off the phone, so it answers with no signal -
      // and it has to run before the list is drawn or a form he started this
      // morning looks untouched.
      ref.read(draftProvider.notifier).load();

      // Rides on the tags: this screen is the one place he reliably opens with
      // signal, and the form itself only ever reads the phone.
      refreshFormOptions(ref);
    });
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final tags = ref.watch(tagProvider);
    final uploads = ref.watch(uploadProvider);
    final drafted = ref.watch(draftProvider).draftTagIds;
    final search = ref.watch(searchProvider);

    // The server sends the two lists already ordered - newest batch then code
    // for the work left, most recently filed first for the work done. Neither
    // is re-sorted here.
    //
    // A pole he has filed but not yet uploaded stays under Assigned. His call:
    // it is pending, not completed, and filing it under Completed told the
    // crew the office had it. It used to sit at the top of Completed on the
    // argument that he would otherwise walk back and tag the pole twice - what
    // actually stops that is the dialog on the row, which asks before letting
    // him replace a saved record.
    final waiting = uploads.waitingTagIds;

    // Half-filled forms ride to the top of their tab. Left in place they sat in
    // code order among forty others, and the one row on the screen he has
    // already spent ten minutes on was the one he had to hunt for.
    //
    // Not a card above the list, which is what the mockup draws: a card
    // assumes there is one, and he can leave four half-done in an afternoon.
    // Pinned rows read the same whether there is one or six.
    //
    // Order within each group is left alone. The drafts keep the order the
    // server sent them in, and so does everything under them.
    List<Tag> draftsFirst(Iterable<Tag> rows) {
      final all = rows.toList();
      return [
        ...all.where((tag) => drafted.contains(tag.tagId)),
        ...all.where((tag) => !drafted.contains(tag.tagId)),
      ];
    }

    // Everything the office still has open for him, poles waiting to upload
    // included.
    //
    // Only what he has accepted. The server sends nothing else - a tag he has
    // not claimed cannot carry a pole record, so a row here would be one he
    // could tap and not finish. Accepting is its own act, on its own screen.
    final assigned = draftsFirst(tags.tags.received);

    // Poles the office has sent back, in a tab of their own.
    //
    // They sat under Assigned with the rest, and before that had a tab split
    // out by whether the tag carried a remark - which is the version that was
    // wrong, because a remark can mean anything. The server now says outright
    // which poles are going back and which of the three trips each one is, so
    // the split is a fact rather than a guess.
    //
    // Its own tab because it is not the same job. A pole here is one he has
    // already been to and filed; what he owes it is a pin, or photographs, or
    // the whole form again, and the row has to tell him which before he sets
    // out.
    final rework = draftsFirst(tags.tags.rework);

    final completed = tags.tags.completed;

    // Handed to both tabs rather than wrapped around them. A RefreshIndicator
    // above a TabBarView never fires: the pull it is listening for happens
    // inside the page view, a scrollable of its own, and the notification
    // reaches the indicator already marked as somebody else's. The pull has to
    // sit on the list being pulled.
    //
    // Both calls, because this pull is him deliberately asking to be brought
    // up to date - and it is the only way a pole type added at the office
    // reaches him without restarting the app.
    Future<void> refresh() async {
      // The queue first, then the list, and the order is the whole point: a
      // pole that goes up now should come back down as Completed in the same
      // pull rather than a pull later.
      //
      // Retried here at all because this is the gesture a man reaches for when
      // he is standing there with signal watching "Pending upload". Until now
      // the queue woke on three things - the app opening, the app coming back
      // to the foreground, and the network reconnecting - and none of them
      // covers the case that actually happens: his signal never dropped, the
      // office server was down for ten minutes. Nothing told the phone the
      // world had changed, so the pull re-read the list and left his work
      // sitting on the handset.
      await ref.read(uploadProvider.notifier).drain();
      await ref.read(tagProvider.notifier).loadMyTags();
      await refreshFormOptions(ref);
    }

    final header = HomeHeader(
      user: user,
      onLogout: () => signOut(ref),
      // The server's figures, not the two lists totalled. The lists
      // are capped, so counting them reported the cap once he passed
      // it - and neither of them says whether a bundle is finished.
      stats: tags.stats,
      // What the server has yet to hear about. Only the "done
      // today" figure uses it now - the poles themselves stay under
      // Assigned, so the "left" tile counts them like any other.
      waiting: waiting.length,
      syncedAt: tags.syncedAt,
      isLoading: tags.isLoading,
      isOffline: tags.error != null,
      // Pushed, not gone to: it is a look at his own figures and he
      // comes straight back to the list he was reading.
      onOpenWork: () => context.push(Routes.work),
    );

    // The strips that only draw when they have something to say.
    //
    // Awaiting sits above the upload line, and that ordering is the point:
    // one is work he cannot start until he taps, the other is work already
    // done and merely waiting on signal. The thing blocking him reads first.
    final strips = <Widget>[
      // Counted from the header's own figures rather than by fetching the
      // list. The strip only has to know whether to draw, and asking for the
      // list every time the app opens is a request per morning to be told
      // nothing is waiting.
      if (tags.stats.hasWaitingBatches)
        AwaitingLine(
          count: tags.stats.awaitingBatches,
          // Pushed, so backing out of it lands here rather than on the
          // spinner the app started from. Accepting reloads his tags on
          // the way back, which is why nothing is refreshed here.
          onTap: () => context.push(Routes.accept),
        ),
      if (uploads.waiting > 0) WaitingLine(count: uploads.waiting),
      for (final tag in uploads.failed) RefusedLine(tag: tag),
      if (tags.error != null && !tags.tags.isEmpty)
        ErrorBanner(message: tags.error!),
    ];

    // The heading and the search box, as one block. The heading says what the
    // whole block under it is for, once, rather than leaving the search box
    // to imply it. The rules either side put a break between the green block
    // above and the list below.
    final finder = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Divider(height: 1, thickness: 1, color: AppColors.line),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Pick from your list',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Expanded(
                child: Divider(height: 1, thickness: 1, color: AppColors.line),
              ),
            ],
          ),
        ),
        SearchBox(
          controller: _typed,
          onTyped: ref.read(searchProvider.notifier).search,
          onClear: () {
            _typed.clear();
            ref.read(searchProvider.notifier).clear();
          },
        ),
      ],
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        bottomNavigationBar: ScanButton(onTap: () => context.push(Routes.scan)),
        body: Column(
          children: [
            // A green cap over the status bar, held there while everything
            // under it scrolls.
            //
            // The green header used to paint its own way past the status bar,
            // which worked while it never moved. Now that it slides up out of
            // the way, the light status icons would be left over a white page
            // and vanish. The cap is the same green standing in for it.
            Container(
              height: MediaQuery.paddingOf(context).top,
              color: AppColors.deepGreen,
            ),
            Expanded(
              // The cap has spent the top inset, so the header below must not
              // reserve it a second time.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                // The green block, the strips and the finder scroll away with
                // the list; the tabs stop at the top and stay.
                //
                // Stacked and fixed, the furniture came to around 390 and a
                // small handset gives about 640 - with a batch waiting and the
                // server down, the list was left ten pixels to live in. It is
                // the one thing on the page he came for, so it is the one
                // thing that gets the room.
                //
                // Standing still nothing has changed: he opens the app and
                // sees exactly what he saw before, because at the top of the
                // list the header is at its full height.
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [header, ...strips, finder],
                      ),
                    ),
                    // The tabs step aside while he is searching rather than
                    // sitting above the results. A result can come from
                    // either of them, and a tab bar over one list would have
                    // him reading "Assigned · 21" above a finished pole from
                    // June.
                    if (!search.isActive)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedTabs(
                          TagTabs(
                            assigned: assigned.length,
                            rework: rework.length,
                            completed: completed.length,
                          ),
                        ),
                      ),
                  ],
                  body: search.isActive
                      ? SearchResults(
                          search: search,
                          queued: uploads.queuedTagIds,
                          waiting: waiting,
                          drafted: drafted,
                        )
                      : TabBarView(
                          children: [
                            HomeBody(
                              key: const PageStorageKey('assigned'),
                              state: tags,
                              tags: assigned,
                              queued: uploads.queuedTagIds,
                              waiting: waiting,
                              drafted: drafted,
                              onRefresh: refresh,
                              emptyTitle: 'No tags assigned to you yet',
                              emptyDetail:
                                  'Ask your dispatcher to assign you a batch.',
                              listLabel:
                                  'Tap a tag to scan · ${assigned.length} '
                                  'waiting',
                            ),
                            HomeBody(
                              key: const PageStorageKey('rework'),
                              state: tags,
                              tags: rework,
                              queued: uploads.queuedTagIds,
                              waiting: waiting,
                              drafted: drafted,
                              onRefresh: refresh,
                              emptyTitle: 'Nothing to fix',
                              emptyDetail:
                                  'Poles the office wants looked at again '
                                  'appear here, with the reason.',
                              listLabel: '${rework.length} to fix',
                            ),
                            HomeBody(
                              key: const PageStorageKey('completed'),
                              state: tags,
                              tags: completed,
                              queued: uploads.queuedTagIds,
                              waiting: waiting,
                              drafted: drafted,
                              onRefresh: refresh,
                              emptyTitle: 'No completed records',
                              emptyDetail:
                                  'Records appear here once a pole has been '
                                  'submitted.',
                              listLabel: '${completed.length} submitted',
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tabs, held at the top of the list while the green scrolls away behind
/// them.
///
/// Painted on the page colour rather than left clear: a pinned header is
/// drawn over the list, and without a fill the rows would slide up through
/// the words.
class _PinnedTabs extends SliverPersistentHeaderDelegate {
  const _PinnedTabs(this.tabs);

  final Widget tabs;

  /// What [TagTabs] comes to: 6 above, 4 of padding, a 46 tab, 4 again, 10
  /// below. A sliver has to be told, so this has to be kept in step with it.
  static const double _height = 70;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(color: AppColors.page, child: tabs);
  }

  @override
  bool shouldRebuild(_PinnedTabs old) => old.tabs != tabs;
}
