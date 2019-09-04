---
title: "Release v1.0.5"
description: ""
date: 2019-09-04T10:02:34+02:00
publishDate: 2019-09-04T10:02:34+02:00
author: "Erazem Kokot"
images: []
draft: false
tags: ["releases"]
---

Another Anarchy update, yay!

1.0.5's changelog is actually quite long, despite being a "patch" version.

You can check out the changelog [on our release page](https://github.com/deadhead420/anarchy-linux/releases/tag/v1.0.5) for a summary or continue reading for a more in-depth look into the changes.

Firstly we've completely removed the GUI installer, since it was very outdated and it hasn't been built since like v1.0.0.
AFAIK nobody has complained about the lack of GUI builds, but if enough people would like it back, it can be arranged, although we'd need some maintainers for it.
This does not affect the installation of DEs and WMs, you can still choose all the ones you could before, it's just that the installation takes place in a terminal.

We've also refactored the `anarchy-creator.sh` script to more closely follow bash best practices
and we've renamed it to `iso-generator.sh` to make it less confusing, since anarchy-creator and anarchy-installer are similarly named, but do completely different things.
Maybe we'll move the anarchy-installer script to somewhere else at some point.

Something quite important was also added in v1.0.5:
We've started generating proper checkums.
You should now be able to use `sha256sum` to check if the image was properly downloaded.

`arch-wiki(-cli)` was also completely removed in this version.
To be fair, it was removed in v1.0.4 already, but the menu option still existed and didn't work, so now it's finally gone.

For those of you who want to compile your own Anarchy installers,
we've made the script more verbose, with more helpful info and proper error exits.

French translations were updated, GREP_OPTIONS was removed from .zshrc,
OpenJDK7 was replaced by OpenJDK8 in the optional software menu and OpenJDK11 & 12 were added as well.
Also in the list of added packages were `youtube-dl` and `openssh`
(which was added by default to our quick server installations)

The insertion of modules into `mkinitcpio.conf` was fixed and the issue of LUKS-encryped XFS installations not booting was resolved as well.

On the Github side of things we've also updated the README and have added issue and pull request templates - please use them.

A [contributing guide](https://github.com/deadhead420/anarchy-linux/blob/master/CONTRIBUTING.md) was also added, which can give you some ideas on how to contribute to the project.


Well, that just about sums it up, see you when the next release comes out ;)
