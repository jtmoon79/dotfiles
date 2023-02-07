#!/usr/bin/env python3
#
# print various locale information
#
# derived from https://stackoverflow.com/questions/54625182/what-is-the-list-of-python-settings-that-affect-encoding-decoding-and-printing/54625183#54625183

import locale
import os
import sys


def main():

    print("Python:")
    print("  version:", sys.version.replace("\n", " "))
    print("  platform:", sys.platform)
    print("  executable:", sys.executable)
    print("  prefix:", sys.prefix)
    print()

    print("environment:")
    for env in (
        "LC_ALL",
        "LANG",
        "LC_CTYPE",
        "LANGUAGE",
        "PYTHONUTF8",
        "PYTHONIOENCODING",
        "PYTHONLEGACYWINDOWSSTDIO",
        "PYTHONCOERCECLOCALE",
    ):
        if env in os.environ:
            print("  \"%s\"=\"%s\"" % (env, os.environ[env]))
        else:
            print("  \"%s\" not set" % env)
    print("  -E (ignore PYTHON* environment variables) ?", bool(sys.flags.ignore_environment))

    print()
    print("sys module:")
    print("  sys.getdefaultencoding() \"%s\"" % sys.getdefaultencoding())
    print("  sys.stdin.encoding \"%s\"" % sys.stdin.encoding)
    print("  sys.stdout.encoding \"%s\"" % sys.stdout.encoding)
    print("  sys.stderr.encoding \"%s\"" % sys.stderr.encoding)
    print("  sys.getfilesystemencoding() \"%s\"" % sys.getfilesystemencoding())

    print()
    print("locale module:")
    if hasattr(locale, "nl_langinfo"):
        print("  locale.nl_langinfo(locale.CODESET) \"%s\""
            % locale.nl_langinfo(locale.CODESET))
    else:
        print("  locale.nl_langinfo not available")

    try:
        print("  locale.getencoding() \"%s\"" % locale.getencoding())
    except AttributeError:
        print("  locale.getencoding() not available")

    try:
        print("  locale.getlocale()", (locale.getlocale(),))
    except AttributeError:
        print("  locale.getlocale() not available")

    try:
        print("  locale.getpreferredencoding() \"%s\""
            % locale.getpreferredencoding())
    except AttributeError:
        print("  locale.getpreferredencoding() not available")

    try:
        print("  locale.getdefaultlocale()[1] \"%s\""
            % locale.getdefaultlocale()[1])
    except AttributeError:
        print("  locale.getdefaultlocale() not available")

if __name__ == "__main__":
    main()
