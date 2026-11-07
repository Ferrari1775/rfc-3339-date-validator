# rfc-3339-date-validator

Checks whether a shell string is a valid RFC 3339 date-time.

```bash
source rfc_3339_date_validator.sh

if rfc3339_is_valid '2023-01-15T12:30:45Z'; then
    echo 'valid'
fi

rfc3339_is_valid '2023-02-29T00:00:00Z' || echo 'not valid: Feb 29 in a non-leap year'
```

The library exports exactly one function:

- `rfc3339_is_valid <string>` — returns `0` if the argument is a valid RFC 3339
  date-time, `1` otherwise. It never prints anything.

## Why this exists

The obvious way to validate a date in shell is to hand the string to `date` and
see whether it complains. That route is a trap. GNU `date -d` and BSD `date -j`
accept different, looser grammars, neither round-trips a leap second
(`23:59:60`), and both consult the local timezone, so the same string can pass
on one machine and fail on another. RFC 3339 is a wire format; validation
should not depend on the host's clock or zone database.

So this library is a self-contained parser: a single POSIX ERE match for the
shape, followed by integer range checks and a calendar-aware day check. It has
no dependencies beyond bash builtins and coreutils, and it is deterministic —
the same string gives the same answer on every machine.

The trade-off: the function answers "is this string well-formed?", not "does
this instant exist in the tz database?". It will accept an offset like
`+14:00` even though no inhabited place uses it, because RFC 3339 permits any
offset in `-23:59`..`+23:59`. If you need the instant, parse the offset
yourself after validation.

## The awkward edge

A purely lexical validator accepts `2023-02-31T00:00:00Z`, because `31` is a
plausible-looking day number. This library does not: it knows February has 28
or 29 days, that 1900 was not a leap year, and that 2000 was. If you were
expecting a regex-only check, that is the behaviour that will surprise you.

A second, smaller edge: the `T` separator and the `Z` suffix are accepted in
both cases (`t`, `z`), because RFC 3339 section 5.6 allows producers to
lowercase them.

## Running the tests

```bash
bash test_rfc_3339_date_validator.sh
```
