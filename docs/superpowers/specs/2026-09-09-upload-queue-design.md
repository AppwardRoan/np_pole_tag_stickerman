# Submit and upload — design

**Date:** 2026-09-09
**App:** `np_pole_tag_stickerman`
**Backend:** `../np-pole-tag-api` — no changes needed

---

## The problem

`tag_form_screen.dart:234` says *"Everything is filled in. Sending is not built yet."*

Juan can fill in the whole form and take his photos, and then nothing happens. The
work exists only as widget state, and it dies when he leaves the screen.

The obvious fix — send it to the server on Submit — does not survive the job.
Poles are in places with no bars. A submit that requires signal is a submit that
fails most of the afternoon.

## The shape of the fix

Submit writes the tag to the phone. Uploading is a separate thing that happens
whenever it can.

1. Submit saves the tag on the phone
2. Signal → uploads right away
3. No signal → uploads later, by itself
4. Home screen counts what's waiting
5. Refused tags go red
6. Submitted tags go grey on the list
7. Logging out doesn't delete the queue

Everything below is detail on those seven.

---

## 1. Submit saves the tag on the phone

Submit stops being a network call. It becomes a write to local storage, and it
always succeeds.

What gets written:

- the form answers — the same fields `PoleTaggingRecordCreate` accepts
- the paths of his photos
- which upload step it has reached

**Photos have to be copied first.** The camera writes to a temp folder that
Android clears whenever it wants space. A tag that waits overnight would come
back in the morning with its photos gone. So Submit copies each shot into the
app's own documents folder and stores *those* paths.

Storage is Hive, matching `tag_cache.dart`. Same reason it was chosen there: the
entry is a plain map, so there is no code generation step.

## 2. Signal → uploads right away

Immediately after the write, the sender runs. With signal, the tag is uploaded and
gone within a second or two.

So on a normal day the queue is invisible. It only becomes real when the signal
does not.

## 3. No signal → uploads later, by itself

The sender runs at three moments:

- the app opens, or comes back from his pocket
- the network returns while the app is open
- straight after a Submit

Juan never presses anything. There is no sync button and no settings screen.

**The app must be open.** Phone in pocket with the app closed uploads nothing.

That is a deliberate choice, not an oversight. Background upload was considered and
dropped: Xiaomi, Oppo, Vivo and Realme all kill background work aggressively to
save battery, so on the cheap handsets crews actually carry it would fire
unreliably or not at all. It buys, at best, the difference between uploading at
5:20pm during the ride home and 6pm when he opens the app. It can be added later
without changing anything below.

### How one tag uploads

One tag at a time, oldest first. Not in parallel — gentler on a weak connection
and far easier to reason about when something goes wrong.

For each tag:

1. `POST /pole-records` with the form answers → the server returns a `record_id`
2. `POST /pole-records/{record_id}/photos` for each photo, one at a time
3. all through → delete the copied photos, remove the entry

The entry remembers the `record_id` and which photos have gone. A retry after a
failure at photo 3 of 5 resumes at photo 3. It does not re-post the record and
does not re-send photos 1 and 2.

Retrying the record itself is safe anyway: `create_pole_record` returns **200 with
the existing record** when one already exists for that tag, rather than erroring.
So a reply lost on a flaky connection cannot produce a duplicate.

## 4. Home screen counts what's waiting

A line at the top of "My Tags":

> **3 tags waiting to upload**

Present only when the count is above zero. It goes down on its own. Tapping it
shows which tags they are — codes and times, nothing to press.

## 5. Refused tags go red

Two kinds of failure, and they need opposite handling.

**Temporary** — no signal, timeout, server unreachable. The server never heard the
request. Retrying is the whole point of the queue.

**Permanent** — the server heard it and said no. Retrying will get the same answer
tomorrow. The backend already produces these:

| Status | Meaning |
|---|---|
| 403 | that tag is not assigned to you — the dispatcher gave it to another crew |
| 404 | tag not found in your organization |
| 400 | a form choice is not one of your organization's options |
| 409 | this pole already has a photo of that type |
| 413 | photo is over the 10MB cap |
| 422 | the request did not validate |

A permanent refusal stops the retries for that tag and shows it in red, carrying
the server's own `detail` text:

> **NP-3F7K — could not upload. That tag is not assigned to you.**

It stays on the phone. Nothing is deleted — the photos and the answers are still
there, which is what lets a supervisor sort it out. And it does not block the
queue: the tags behind it upload normally.

`401` is neither kind. It means the login expired — see *Login expiry* below.

## 6. Submitted tags go grey on the list

The server marks a tag Installed when the record lands. Until then it does not
know, so "My Tags" would keep showing a pole Juan finished hours ago as still to
do — and he could walk back and tag it twice.

The phone knows, though. The queue is right there. So the list checks it while
drawing:

- tag is in the queue → **greyed out**
- tag uploads → it drops off the list the normal way

Colour only. No badge, no label, no separate section.

## 7. Logging out doesn't delete the queue

`logout()` clears the token and the cached user. It must not touch the queue.

This matters more than it sounds. Tokens last 30 minutes and there is no refresh,
so a Juan who logs in at 7am and opens the app at 6pm gets a 401 and is signed
out. If that took his six waiting tags with it, a day of work would be gone.

Signed out, the queue simply waits. He logs in, and it uploads.

### Login expiry — deliberately not solved here

Two better fixes exist and both are out of scope:

- **Longer tokens.** `ACCESS_TOKEN_EXPIRE_MINUTES` is one setting, but it is
  global — it would lengthen logins for the admin app too. That is a separate
  decision, not something to change quietly inside this work.
- **Refresh tokens.** The correct answer, and a piece of work in its own right.

For now: a 401 during upload pauses the queue and signs him out, as it does today.
Nothing is lost. He logs in again and it drains.

---

## What Juan sees — the exact words

| Situation | After Submit | Home screen |
|---|---|---|
| Has signal | *Tag uploaded.* | — |
| No signal | *Tag saved. Will upload later.* | *1 tag waiting to upload* |
| Two more | *Tag saved. Will upload later.* | *3 tags waiting to upload* |
| Queue drains | — (a bar slides up: *3 tags uploaded.*) | — |
| Refused | — | *NP-3F7K — could not upload. <reason>* in red |

Notes on the wording:

- **"tag", not "pole"**, throughout — it is the app's existing vocabulary
  ("My Tags", "Scan tag").
- **"upload", not "send"** — on a screen listing tags he still has to install,
  *"1 tag waiting"* would read as *"1 tag left to do"*. "Upload" cannot be
  misread that way.
- The drain message is a **transient bar**, not a phone notification. He finds out
  the moment it happens, wherever he is in the app, and nothing is left in his
  tray to swipe away tomorrow.

---

## Decisions taken without a separate discussion

- **Shrink photos before upload.** A high-res phone shot is 4-8MB and there are up
  to five per tag. Compress to roughly 1MB — still far more than enough to read a
  tag code. The 10MB server cap then cannot be hit in normal use.
- **Delete the copied photos once the tag is uploaded.** Otherwise the phone fills
  up inside a week.
- **A waiting tag cannot be edited.** Submit is final. Fixing a mistake is the
  office's job. This keeps the queue a thing that only remembers and sends, and
  it matches the backend, which refuses a second record for the same pole.

## Deliberately out of scope

- Background upload with the app closed
- Refresh tokens or a longer login
- Editing or deleting a tag that is waiting
- Listing or deleting photos already on the server (`router/photos.py` has upload
  only; the rest is a later piece of work)

---

## Technical notes

### Endpoints used

**`POST /pole-records`** → 201, or 200 with the existing record

```
tag_id, latitude, longitude, gps_accuracy,
pole_type_id, pole_condition_id, telco_option_id, streetlight_option_id,
height_ft, height_m, remarks
```

**`POST /pole-records/{record_id}/photos`** → 201, multipart

```
file        the image
photo_type  tag_closeup | full_pole | surroundings | extra
taken_at    optional
```

Shot order maps to type by index — `ShotsScreen.labels` is already in this order:

| Index | `photo_type` |
|---|---|
| 0 | `tag_closeup` |
| 1 | `full_pole` |
| 2 | `surroundings` |
| 3, 4 | `extra` |

Both spares share `extra`: the type says what the shot is *of*, and the two
spares are the same shot.

### Files

New:

- `lib/models/queued_tag.dart` — one waiting tag: answers, photo paths, state,
  `record_id`, photos already sent, failure reason
- `lib/services/upload_queue.dart` — the Hive box. Add, read, update, remove.
  Touches only the phone
- `lib/services/photo_store.dart` — copy out of temp, compress, delete when done
- `lib/services/uploader.dart` — the sender. Walks the queue, calls the API,
  decides temporary vs permanent
- `lib/providers/upload_providers.dart` — exposes the count and the state to the
  screens; owns the three triggers

Changed:

- `lib/services/api_services.dart` — add `createPoleRecord` and `uploadPhoto`.
  Photo upload is `http.MultipartRequest`, so it cannot use `_authHeaders`
  wholesale — that sets `Content-Type: application/json`
- `lib/screens/tag_form_screen.dart` — replace the placeholder at line 233
- `lib/screens/home_screen.dart` — the counter, and grey rows for queued tags

### Packages to add

- `connectivity_plus` — to notice the network returning
- `path_provider` — the app's permanent documents folder
- `flutter_image_compress` — shrinking photos

### Testing

The app has no tests today. Worth having for this, because the failure paths are
exactly what cannot be checked by hand at a desk:

- a queued tag survives a restart, photos included
- retry after a failure at photo 3 resumes at photo 3, and does not re-post the record
- a 403 turns the tag red and leaves the ones behind it uploading
- a timeout leaves the tag waiting, not red
- logout leaves the queue intact
- a submitted tag greys out on the list immediately

The uploader should take the API service as a parameter so a fake can be passed
in. Without that, none of the above is testable.

---

## Open question for later

`router/photos.py` has upload only — no list, no delete. So a blurry photo is
permanent, and nothing can show the office which shots a pole actually has.
Agreed to leave it; worth picking up after this.
