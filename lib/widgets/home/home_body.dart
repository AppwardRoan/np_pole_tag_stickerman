import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/models/tag.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/home/empty_message.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_row.dart';

class HomeBody extends StatelessWidget {
  const HomeBody({
    required this.state,
    required this.tags,
    required this.queued,
    required this.waiting,
    required this.drafted,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptyDetail,
    required this.listLabel,
    super.key,
  });

  /// The load itself - whether it is running, and whether it failed. Shared by
  /// both tabs, because one request fills them both.
  final TagState state;

  /// This tab's share of [TagState.tags], already split by the caller.
  final List<Tag> tags;

  /// Tag ids he has already submitted. The server still calls them Dispatched
  /// because it has not heard yet, so this is the only thing that knows.
  final Set<int> queued;

  /// Of those, the ones still on their way up rather than refused. What
  /// separates a row he may still fill in again from one he may not.
  final Set<int> waiting;

  /// Tag ids with a form he started and did not finish.
  final Set<int> drafted;

  /// Pull-to-refresh, owned by each tab rather than by the screen. See the
  /// note where it is built.
  final Future<void> Function() onRefresh;

  /// What this tab says when it has nothing in it. The two tabs are empty for
  /// opposite reasons - nobody has given him work, or he has not done any yet
  /// - and one wording cannot cover both.
  final String emptyTitle;
  final String emptyDetail;

  /// The small line of capitals over the list, saying what the rows are for.
  /// Each tab words it differently - one is work to do, the other is work done.
  final String listLabel;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: onRefresh, child: _list(context));
  }

  Widget _list(BuildContext context) {
    if (tags.isNotEmpty) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        // One more than there are tags: the label rides at the top of the list
        // rather than above it, so it scrolls away with the rows it describes.
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox.shrink(),
        itemBuilder: (_, position) {
          if (position == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Text(
                listLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.muted,
                ),
              ),
            );
          }

          final index = position - 1;

          return TagRow(
            tag: tags[index],
            // Greyed only once the office actually has it. A pole still
            // waiting on his phone sits in Assigned now, and fading a row in
            // his own work list reads as "ignore this" - the Waiting chip is
            // what says the office has yet to hear.
            done: tags[index].status == TagStatus.used,
            // Still on its way up. The chip says so, and it is what lets him
            // back in to fill the record again before it goes.
            waiting: waiting.contains(tags[index].tagId),
            // Submitted wins: a tag cannot be both, and if the two ever
            // disagreed, "done" is the one he must not be sent back to.
            draft:
                !queued.contains(tags[index].tagId) &&
                drafted.contains(tags[index].tagId),
          );
        },
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Everything below is a message rather than a list, and a message cannot
    // be pulled down. Scrolled here so it can be: an empty tab is exactly
    // where he reaches for a refresh, and a screen that ignores the pull reads
    // as a screen that is stuck.
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            // Stretched, or nothing here is in the middle of the screen. A
            // Column sizes itself to its widest child, the ConstrainedBox
            // takes that width in turn, and the scroll view puts what it is
            // given against its left edge - so the icon and the two lines sat
            // 183 device pixels left of centre, centred only on each other.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only when this tab has nothing to show. A failed refresh with
              // the phone's saved list still up is the banner's job, not this
              // one's.
              state.error != null
                  ? EmptyMessage(
                      icon: Icons.cloud_off,
                      title: 'Could not load your tags',
                      detail: state.error,
                    )
                  : EmptyMessage(
                      icon: Icons.inbox,
                      title: emptyTitle,
                      detail: emptyDetail,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
