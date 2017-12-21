# Changelog

`git log` is another good way to peer into the innards of this repository.


# msaint's revisions

## 4.3.3

### r23

2012-04-11 01:25:41 +0000 (Wed, 11 Apr 2012)

- Added options to save, load, and delete outfits.


## 4.3.0

### r22

2012-03-29 18:43:43 +0000 (Thu, 29 Mar 2012)

- Minor bug fix.  Has no impact on current code, but should be corrected in case it is used in a future version.

### r21

2012-03-26 02:20:54 +0000 (Mon, 26 Mar 2012)

- Tagging as 1.11-beta

### r20

2012-03-26 02:20:28 +0000 (Mon, 26 Mar 2012)

- Added an important acknowledgment in comments.

### r19

2012-03-26 02:16:41 +0000 (Mon, 26 Mar 2012)

- Added pre-fetching of item data for default weapons used to force correct weapon loading sequence in dressing room.

### r18

2012-03-26 01:21:16 +0000 (Mon, 26 Mar 2012)

- Added generic race-sex models.  Minor improvements to dressing function.

### r16

2012-03-18 05:32:23 +0000 (Sun, 18 Mar 2012)

- Various measures to avoid Win 64-bit and Mac bug where calling GetTransmogrifySlotInfo before inventory data is loaded crashes the client.  Changed to using PLAYER_EQUIPMENT_CHANGED to ensure that all data, including transmog data, is ready when items are queried.

### r14

2012-03-15 16:06:00 +0000 (Thu, 15 Mar 2012)

- Reorganized and improved comments for code readability.  Small changes to tighten up code.  No changes in functionality.

### r12

2012-03-15 01:46:35 +0000 (Thu, 15 Mar 2012)

- Added call to addon initialization code (hooks, ui setup, etc., ...) at PLAYER_LOGIN due to mysteriously not catching ADDON_LOADED on one tested client. Sigh.

### r10

2012-03-14 00:16:02 +0000 (Wed, 14 Mar 2012)

- All library and api calls declared locally, small edits for clarity and efficiency.

### r8

2012-03-13 23:32:02 +0000 (Tue, 13 Mar 2012)

- Added top tab to side dressup, and full addon functionality for the that frame.  Items tried on are tracked separately for the two dressup frames.

### r7

2012-03-13 00:27:12 +0000 (Tue, 13 Mar 2012)

- Added left click pulldown menu to button. Addon can now be entirely controlled using button attached to side of DressUpFrame.  Cleaned up code and comments.

### r6

2012-03-12 01:17:06 +0000 (Mon, 12 Mar 2012)

- Turned off debugging messages, i.e. set DEBUG to nil.

### r5

2012-03-12 01:14:55 +0000 (Mon, 12 Mar 2012)

- Added name tab to top right of DressUpFrame showing the name of the character currently shown.  This button will be used to open character selection.

### r4

2012-03-11 18:55:26 +0000 (Sun, 11 Mar 2012)

- Chosen alt persists as default model.  '/lboy reset' to reset to current character.  Cleaned up debug / chat messages.

### r3

2012-03-11 03:01:54 +0000 (Sun, 11 Mar 2012)

- Cosmetic fixes

### r2

2012-03-11 03:00:12 +0000 (Sun, 11 Mar 2012)

- Initial version with command line only.

### r1

2012-03-11 02:57:03 +0000 (Sun, 11 Mar 2012)

- looksbetteronyou/mainline: Initial Import
