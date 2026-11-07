#!/usr/bin/env bash
# rfc-3339-date-validator: a small shell library that checks whether a string is
# a valid RFC 3339 date-time.
#
# The check is purely lexical plus range validation on the numeric fields; it
# never consults the system clock or the system timezone database. That is a
# deliberate choice: RFC 3339 allows leap seconds (":60") and arbitrary UTC
# offsets, neither of which a call to `date` can round-trip portably. So we
# validate the grammar and the field ranges ourselves and leave the question
# "is this instant in the past?" to the caller.

set -euo pipefail

# rfc3339_is_valid <string>
#
# Returns 0 if the argument is a syntactically valid RFC 3339 date-time, 1
# otherwise. Accepts the "full-date T full-time" form only (no space separator,
# no bare date, no bare time).
#
# We deliberately accept both uppercase and lowercase T/Z because RFC 3339
# section 5.6 says the T and Z may be lowercased by applications, and real
# producers do it.
#
# The format is:
#   date-fullyear "-" date-month "-" date-mday
#   "T"
#   time-hour ":" time-minute ":" time-second [time-secfrac]
#   time-offset
# where time-offset is either "Z"/"z" or ("+"/"-") time-hour ":" time-minute.
#
# Leap seconds (second == 60) are accepted, because RFC 3339 section 5.7
# explicitly permits them.

rfc3339_is_valid() {
    local input=${1-}

    # The regex below is the whole grammar. We anchor it with ^...$ so that
    # trailing junk is rejected. Bash's [[ =~ ]] uses POSIX ERE, which has no
    # non-capturing groups, so we use plain groups and rely on the anchor.
    local re='^([0-9]{4})-([0-9]{2})-([0-9]{2})[Tt]([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]+)?([Zz]|[+-][0-9]{2}:[0-9]{2})$'

    if [[ ! $input =~ $re ]]; then
        return 1
    fi

    # BASH_REMATCH is populated by the successful match above.
    local year=${BASH_REMATCH[1]}
    local month=${BASH_REMATCH[2]}
    local day=${BASH_REMATCH[3]}
    local hour=${BASH_REMATCH[4]}
    local minute=${BASH_REMATCH[5]}
    local second=${BASH_REMATCH[6]}
    local offset=${BASH_REMATCH[8]}

    # Strip leading zeros so that arithmetic below is base-10 and not octal.
    # `10#` is the portable bash way to force base 10; "08" would otherwise be
    # an invalid octal literal in arithmetic context.
    year=$((10#$year))
    month=$((10#$month))
    day=$((10#$day))
    hour=$((10#$hour))
    minute=$((10#$minute))
    second=$((10#$second))

    # Year: RFC 3339 says four digits, and that is what the regex enforced.
    (( year >= 0 )) || return 1

    (( month >= 1 && month <= 12 )) || return 1
    (( day >= 1 && day <= 31 )) || return 1
    (( hour >= 0 && hour <= 23 )) || return 1
    (( minute >= 0 && minute <= 59 )) || return 1

    # Seconds: 0-59 normally, 60 for a leap second.
    (( second >= 0 && second <= 60 )) || return 1

    # Calendar-aware day check. We reject Feb 30, Apr 31, etc. This is the
    # "awkward edge" the README warns about: a purely lexical validator would
    # happily accept 2023-02-31.
    local max_day
    case $month in
        1|3|5|7|8|10|12) max_day=31 ;;
        4|6|9|11)         max_day=30 ;;
        2)
            if (( (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 )); then
                max_day=29
            else
                max_day=28
            fi
            ;;
        *)
            return 1
            ;;
    esac
    (( day <= max_day )) || return 1

    # Offset: Z/z is fine. Otherwise the regex already guaranteed the shape
    # [+-]HH:MM, so we only need to range-check HH and MM.
    if [[ $offset != [Zz] ]]; then
        local off_hour off_minute
        off_hour=$((10#${offset:1:2}))
        off_minute=$((10#${offset:4:2}))
        (( off_hour <= 23 )) || return 1
        (( off_minute <= 59 )) || return 1
    fi

    return 0
}
