# Contributing code

* Follow shell scripting best practices (mostly as described in
[Google's shell style guide](https://google.github.io/styleguide/shell.xml))
* Try to be POSIX compliant (if that's not possible target bash)
* Use `${variable}` instead of `$variable`
* Constants should be `UPPER_CASE`, other variables `lower_case`
* Use single square brackets (`[ condition ]`) for conditionals
(e.g. in 'if' statements)
* Write good comments where needed (e.g. in complicated loops/functions)
* Use different error codes when exiting (0 for proper exit, 1+ for error exits)
and explain them at the top of the file
* Use the `log` function as much as possible (as long as it makes sense)
* Always line wrap at 80 characters
* Scripts don't need a `.sh` suffix and should have a `-` between words
* Libraries (`libs` directory) should always have a `.sh` suffix and an
explanation of what they do
* Neither script nor libraries should be executable (their permissions are
set during compilation)

Check for compliance and errors with [shellcheck](https://www.shellcheck.net/):

`shellcheck -s sh -x <script>`

**Always test your scripts before submitting the PR.**

If you need help remembering commands or want to check out some tips
visit [devhints.io](https://devhints.io/bash) to do so.

# Translating

Anarchy Linux supports a bunch of languages, most of which need maintainers.

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

## Translating new languages

* Ask yourself if you're committed enough to translate the whole file
(check english.conf for size comparison - ~500 translations)
* Copy the `english.conf` file and rename it to your language's
english name (e.g. "portuguese.conf" or "spanish.conf")
* Change the LANG variable to your language's UTF-8 locale (e.g. `sl_SI.UTF-8`)
* Check general rules/recommendations below