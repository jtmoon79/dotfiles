#!/usr/bin/env python3
#
# print various locale information
#
# derived from https://stackoverflow.com/questions/54625182/what-is-the-list-of-python-settings-that-affect-encoding-decoding-and-printing/54625183#54625183

import locale
import os
import sys


print("environment:")
print("  -E (ignore PYTHON* environment variables) ? %s" %
      bool(sys.flags.ignore_environment))
for env in (
    "LC_ALL",
    "LANG",
    "LC_CTYPE",
    "LANGUAGE",
    "PYTHONIOENCODING",
    "PYTHONLEGACYWINDOWSSTDIO"
):
    if env in os.environ:
        print("  \"%s\"=\"%s\"" % (env, os.environ[env]))
    else:
        print("  \"%s\" not set" % env)

print()
print("sys module:")
print("  sys.getdefaultencoding() \"%s\"" % sys.getdefaultencoding())
print("  sys.stdin.encoding \"%s\"" % sys.stdin.encoding)
print("  sys.stdout.encoding \"%s\"" % sys.stdout.encoding)
print("  sys.stderr.encoding \"%s\"" % sys.stderr.encoding)

print()
print("locale module:")
if hasattr(locale, "nl_langinfo"):
    print("  locale.nl_langinfo(locale.CODESET) \"%s\""
          % locale.nl_langinfo(locale.CODESET))
else:
    print("locale.nl_langinfo not available")

print("  locale.getencoding() \"%s\"" % locale.getencoding())
print("  locale.getlocale() %s" % (locale.getlocale(),))
print("  locale.getpreferredencoding() \"%s\""
      % locale.getpreferredencoding())
print("  locale.getdefaultlocale()[1] \"%s\""
      % locale.getdefaultlocale()[1])
