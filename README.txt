Succubus Quiet 3.0 - World of Warcraft: Forever (Beta, interface 16001)

INSTALL: copy SuccubusQuiet into World of Warcraft/_classic_beta_/Interface/AddOns/

SLIDERS (Esc > Options > AddOns > Succubus Quiet, or /sq options)
- Overall sound frequency: 0% silent ... 100% normal.
- Whip / moan balance: 0 = moans only, 50 = balanced, 100 = whips only.
  whip chance = frequency * min(1, balance/50)
  moan chance = frequency * min(1, (100-balance)/50)
Fallbacks: /sq freq 60   /sq balance 80

SETUP - classify the sounds
1. Find the FileDataIDs (Sound ID Finder addon, or wow.tools/files, "succubus").
2. Identify each by ear: /sq test <id>
3. /sq add whip <id>   or   /sq add moan <id>
IDs from v2 are kept in an "other" group that follows the overall slider only.
/sq list shows all groups.

LIMITS
- Addons cannot change animations; only sounds are affected.
- Muting is per sound file, so other succubi using those files are affected.
