# Reporting issues

Before you report any issues with Anarchy, make sure you do the following:


## Update the installer

Have you updated Anarchy before using it?

If so, great, move on to the next step.

Otherwise make sure to always update Anarchy before installing Arch with it,
because your bug might have already been fixed, without you even knowing.

You can update Anarchy in the main menu (shown after booting the iso),
by pressing 2 or executing `anarchy -u`.

If you have not updated Anarchy prior to submitting the issue,
we will send you to this page and expect you to redo your installation
before reporting the bug again.


## Check online for existing issues

No matter what problem you've stumbled upon, you're almost certainly not
the first person to have gotten the error.
Check online for any existing issues, either by copy-pasting the error message
into your favourite search engine, prepending "arch" to the search or even
adding your specific hardware to the search (useful for laptops and any driver
issues - wireless, bluetooth, ...).

You next stops should be the [Arch Wiki](https://wiki.archlinux.org/) and
[Arch Forums](https://bbs.archlinux.org/).


## Share as much info as you can

We can't and won't help you if you don't try and submit as much information
as you can.
This includes logs, screenshots (or pictures of the terminal/error message),
videos etc.

You can share a log of your installation by choosing "Return To Command Prompt"
(option 4) in the final menu or when an error occurs and you are dropped into
a terminal.

You may also locally view the installation log by choosing "View Install Log"
(option 5).

Executing `cat /tmp/anarchy.log | nc termbin.com 9999` will return a short url,
which you should write down and share along with any other info you may have.

_If you don't take the time to do all of the above, then it's not worth our
time to fix the bug, thanks for understanding._

