import 'package:flutter/material.dart';

/// Said instead of offering Replace, on a pole whose record reached the office
/// while its photos did not.
///
/// Shared because he meets it at two doors - the tag row and the Scan button -
/// and it has to be the same fact both times.
Future<void> showAlreadySent(BuildContext context, String tagCode) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Already sent'),
      content: Text(
        'Tag $tagCode is already with the office. Its photos are still '
        'uploading and will finish when there is signal. To change it, ask the '
        'office to send it back.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
