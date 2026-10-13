import 'package:flutter/material.dart';
import 'package:np_pole_tag_stickerman/widgets/tag_form/form_card.dart';

/// The most he can write here.
///
/// Roan's number. The API does not cap `remarks` at all, so this is the only
/// limit there is - a house rule about how long a note anybody will read,
/// rather than a bound the server would enforce.
const int _remarksLimit = 500;

/// Anything the office should know that no field on the form asks about.
class RemarksCard extends StatelessWidget {
  const RemarksCard({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return FormCard(
      label: 'Remarks',
      trailing: 'optional',
      outlined: false,
      child: TextField(
        controller: controller,
        maxLines: 5,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        // The office refuses anything longer, so the box stops him at the
        // pole rather than letting the record queue up and be turned away
        // hours later, when he is somewhere else and cannot shorten it.
        //
        // `maxLength` draws its own counter under the box, which is the whole
        // reason the limit is visible: a cap that only bites on the last
        // keystroke reads as a broken keyboard.
        maxLength: _remarksLimit,
        decoration: const InputDecoration(
          hintText: 'Anything the office should know about this pole',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
