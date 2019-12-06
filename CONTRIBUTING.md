# Contributing guide

So you've decided to contribute to Anarchy Linux, that's great.

There's actually quite a few things you can do to help this project,
so just pick the one that suits you best and start collaborating.

## Submit code

You've probably checked out the project at this point,
but you've found that we forgot to add a feature you'd really like to see.
Most of the project is written with bash scripts,
so if you are already familiar with bash,
you can get right on with contributing.

If you don't have any experience with bash or need a refresher,
check out [devhints](https://devhints.io/)'s [bash cheatsheet](https://devhints.io/bash).

For beginners there are even more good news,
we use `good first issue` and `help wanted` tags,
so you can find some great issues you can help fix [right here](https://github.com/AnarchyLinux/installer/contribute).
Of course you can help fix any issue, those are just the ones we recommend to new contributors.

### Style guide

* Follow bash best practices (Google them)
* Use "${variable}" instead of $variable
* Use double square brackets ("[[ condition ]]") for conditionals
* Use 4 spaces for indentation instead of tabs
* Use "#!/usr/bin/env bash" as a shebang
* Write good comments where needed
* Use different error codes when exiting (0 for proper exit, 1-* for error exits)

If you need help remembering commands or want to check out some tips
visit [devhints.io](https://devhints.io/bash) to do so.

## Update the documentation

Maybe you don't know how to code or don't want to contribute code.
That's ok, we appreciate other kinds of help too.

If you've found a typo in our readme or want to help create [a wiki](https://github.com/AnarchyLinux/installer/wiki),
please do.

## Translating

Anarchy Linux, although a relatively simple project,
still has a bunch of languages included, all of which need contributors.

### Updating existing translations

* Find the file you want to translate and update the strings you want
* If the translations haven't been updated in a while you
can add other maintainers to the Original Maintainer(s) list
* Check below

### Translating for a new language

* Ask yourself if you're committed enough to translate the whole file
(check english.conf for comparison)
* Copy the `english.conf` file and rename it to your language's
english name (e.g. portuguese or spanish)
* Change the LANG variable to your language's UTF-8 locale
* Change the top comment to your file name (e.g. from # english.conf -> # portuguese.conf)
* Check below

### General rules/recommendations

* Make sure to use UTF-8 encoding
* Don't change the variable names (e.g. intro_msg=)
* Don't remove any occurrence of (e.g. \n or \n\n - new lines)
* Don't remove any special characters (e.g. $a, or quotes)
* Don't edit variables within the text (e.g. /dev/${DRIVE} or ${user})
(besides the translations they should look the same)
* Add yourself to the Maintainers list
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

This doesn't apply only to bugs though,
we also accept feature requests, although depending on your wish,
they might not get accepted.

## Conclusion

You can easily see that there are a lot of options for you to contribute to Anarchy.
Feel free to try any one of them, but please create an issue if you wish to add a big feature,
so its inclusion can be discussed and your work won't be for nothing if it does not get included.

And one last thing:

**If you're afraid of contributing, because you think you'll mess something up or something like that,
remember that we are all humans, who make mistakes, and your work will be reviewed before being merged,
so you will always get feedback and help fixing any problem.**

Happy contributing!