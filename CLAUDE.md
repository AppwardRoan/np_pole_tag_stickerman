# CLAUDE.md

Flutter app for the **sticker man** — the field worker who puts the printed tag
on the pole. Talks to the FastAPI backend in `../np-pole-tag-api`; the base URL
is picked in `lib/config/api_config.dart` by setting `_selected` to one of
`deployed`, `emulator` (Android emulator), `wifi` (real phone over wifi) or
`phone` (real phone over USB; needs `adb reverse tcp:8000 tcp:8000`, re-run
after every unplug). A `--dart-define=API_BASE_URL=...` overrides it.

Not a git repository. There is no history to fall back on, so back a file up
before rewriting it.

## Working agreement

**Do not write code until Roan says to.** Explain the problem and the proposed
fix first, in plain language, and wait for an explicit go-ahead on *that fix*.
He reviews every change, so a general "sounds good" earlier in the conversation
is not approval for the edit in front of you — ask again.

Keep explanations short and non-technical unless he asks for detail. Bullets
over paragraphs. One idea at a time; a wall of options reads as noise.
