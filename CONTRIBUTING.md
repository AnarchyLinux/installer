# Contributing guide

Contributing to Anarchy involves downloading the codebase with git (_cloning_)
and then submitting a pull request with any changes you have added.

### Style guide

* Follow bash best practices (mostly as described in
[Google's shell style guide](https://google.github.io/styleguide/shell.xml))
* Use `${variable}` instead of `$variable`
* Constrants should be `UPPER_CASE`, other variables `lower_case`
* Use double square brackets (`[[ condition ]]`) for conditionals
(e.g. in 'if' statements)
* Use 4 spaces for indentation instead of tabs
* Use `#!/usr/bin/env bash` as a shebang
* Write good comments where needed (e.g. in complicated loops/functions)
* Use different error codes when exiting (0 for proper exit, 1+ for error exits)
and explain them at the top of the file (same for returns)
* Use the `log` function as much as possible (as long as it makes sense)
* If possible always line wrap at 80 characters
* Check existing code and try and be consistent
* Scripts don't need a `.sh` suffix and should have a `-` between words
* Libraries (`libs` directory) should always have a `.sh` suffix and an
explanation of what they do

If you need help remembering commands or want to check out some tips
visit [devhints.io](https://devhints.io/bash) to do so.

## Translating

Anarchy Linux, although a relatively simple project,
still has a bunch of languages included, all of which need contributors.

### Translating for a new language

* Ask yourself if you're committed enough to translate the whole file
(check english.conf for size comparison - ~500 translations)
* Copy the `english.conf` file and rename it to your language's
english name (e.g. portuguese.conf or spanish.conf)
* Change the LANG variable to your language's UTF-8 locale (e.g. `sl_SI.UTF-8`)
* Check general rules/recommendations below

### General rules/recommendations

* Make sure to use the UTF-8 encoding
* Don't change the variable names (e.g. intro_msg=)
* Don't remove any occurrence of (e.g. \n or \n\n - new lines)
* Don't remove any special characters (e.g. $a, or quotes)
* Don't edit variables within the text (e.g. /dev/${DRIVE} or ${user})
* Add yourself to the maintainers list
(and your email for possible further communication)
* Compare the finished file with english.conf

_Comparing language files to one another makes Anarchy more consistent
and easier to update in the future._

## Test and report bugs

Even if you don't feel comfortable contributing directly,
there are still some options for you.
You can try the installer, either on your own computer
or in a virtual machine and report back any bugs you may have found.
We will try and fix them as soon as we can, but don't expect immediate responses.
Please make sure to submit logs and all info you can, as described on our
[wiki](https://github.com/AnarchyLinux/installer/wiki/Reporting-issues).

This doesn't apply only to bugs though,
we also accept feature requests, although depending on your wish,
they might not get accepted.