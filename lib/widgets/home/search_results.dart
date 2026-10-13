import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/enums/tag_status.dart';
import 'package:np_pole_tag_stickerman/providers/search_providers.dart';
import 'package:np_pole_tag_stickerman/widgets/home/cut_line.dart';
import 'package:np_pole_tag_stickerman/widgets/home/empty_message.dart';
import 'package:np_pole_tag_stickerman/widgets/home/tag_row.dart';

/// What the box found, and - when it found nothing - which kind of nothing.
class SearchResults extends StatelessWidget {
  const SearchResults({
    required this.search,
    required this.queued,
    required this.waiting,
    required this.drafted,
    super.key,
  });

  final SearchState search;
  final Set<int> queued;
  final Set<int> waiting;
  final Set<int> drafted;

  @override
  Widget build(BuildContext context) {
    if (search.results.isEmpty) {
      if (search.isSearching) {
        return const Center(child: CircularProgressIndicator());
      }

      // Scrolled because the keyboard is up while he is searching, and what is
      // left of the screen under it can be shorter than the message.
      return SingleChildScrollView(
        child: switch (search.outcome) {
          // Not "no such tag". The phone could not ask, and telling him the
          // pole does not exist when it may well is the same lie the scanner
          // used to tell about a sticker it could not look up.
          SearchOutcome.unreachable => const EmptyMessage(
            icon: Icons.cloud_off,
            title: 'Could not search your older poles',
            detail:
                'No signal. What is on this phone found no match - move '
                'somewhere with a bar and try again.',
          ),
          _ => EmptyMessage(
            icon: Icons.search_off,
            title: 'No tag matches “${search.query}”',
            detail: 'Only poles assigned to you appear here.',
          ),
        },
      );
    }

    return Column(
      children: [
        // The one line that keeps the cap honest. Without it the server's 25
        // read as the whole answer, and a pole sitting at number 900 would
        // look like a pole he never tagged.
        if (search.wasCut)
          CutLine(showing: search.results.length, total: search.total),
        Expanded(
          child: ListView.separated(
            itemCount: search.results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final tag = search.results[index];

              return TagRow(
                tag: tag,
                // Greyed only once the office actually has it, the same rule
                // the tabs use. See [HomeBody].
                done: tag.status == TagStatus.used,
                waiting: waiting.contains(tag.tagId),
                draft:
                    !queued.contains(tag.tagId) && drafted.contains(tag.tagId),
              );
            },
          ),
        ),
      ],
    );
  }
}
