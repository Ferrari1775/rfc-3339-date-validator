#!/usr/bin/env bash
# Tests for rfc-3339-date-validator.
#
# Run with:  bash test_rfc_3339_date_validator.sh

set -euo pipefail

# shellcheck source=rfc_3339_date_validator.sh
source "$(dirname "$0")/rfc_3339_date_validator.sh"

failures=0
tests=0

assert_eq() {
    # assert_eq <expected-exit> <input> <description>
    local expected=$1
    local input=$2
    local desc=$3

    tests=$((tests + 1))

    local actual
    if rfc3339_is_valid "$input"; then
        actual=0
    else
        actual=1
    fi

    if [[ $actual -eq $expected ]]; then
        printf 'ok %d - %s\n' "$tests" "$desc"
    else
        printf 'not ok %d - %s\n' "$tests" "$desc"
        printf '  input:    %s\n' "$input"
        printf '  expected: %d\n' "$expected"
        printf '  actual:   %d\n' "$actual"
        failures=$((failures + 1))
    fi
}

# --- Happy path -------------------------------------------------------------
assert_eq 0 '2023-01-15T12:30:45Z'          'UTC Z form'
assert_eq 0 '2023-01-15T12:30:45z'          'lowercase z'
assert_eq 0 '2023-01-15t12:30:45Z'          'lowercase t'
assert_eq 0 '2023-01-15T12:30:45+02:00'     'positive offset'
assert_eq 0 '2023-01-15T12:30:45-05:30'     'negative offset'
assert_eq 0 '2023-01-15T12:30:45.123Z'      'fractional seconds'
assert_eq 0 '2023-01-15T12:30:45.000001Z'   'long fractional seconds'
assert_eq 0 '2023-01-15T00:00:00Z'          'midnight'
assert_eq 0 '2023-01-15T23:59:59Z'          'end of day'

# --- Leap second ------------------------------------------------------------
assert_eq 0 '2016-12-31T23:59:60Z'          'leap second'
assert_eq 0 '2016-12-31T23:59:60+00:00'     'leap second with offset'

# --- Boundary dates ---------------------------------------------------------
assert_eq 0 '2024-02-29T00:00:00Z'          'leap day in leap year'
assert_eq 0 '2000-02-29T00:00:00Z'          'leap day in century leap year'
assert_eq 0 '2023-01-31T00:00:00Z'          '31-day month'
assert_eq 0 '2023-04-30T00:00:00Z'          '30-day month'

# --- Invalid: shape ---------------------------------------------------------
assert_eq 1 ''                             'empty string'
assert_eq 1 'not a date'                    'garbage'
assert_eq 1 '2023-01-15'                    'date only'
assert_eq 1 '12:30:45Z'                     'time only'
assert_eq 1 '2023-01-15 12:30:45Z'          'space instead of T'
assert_eq 1 '2023-01-15T12:30:45'           'missing offset'
assert_eq 1 '2023-01-15T12:30:45+02'        'truncated offset'
assert_eq 1 '2023-01-15T12:30:45Z '         'trailing space'
assert_eq 1 ' 2023-01-15T12:30:45Z'         'leading space'
assert_eq 1 '2023-01-15T12:30:45.Z'         'empty fraction'

# --- Invalid: field ranges --------------------------------------------------
assert_eq 1 '2023-13-15T12:30:45Z'          'month 13'
assert_eq 1 '2023-00-15T12:30:45Z'          'month 0'
assert_eq 1 '2023-01-32T12:30:45Z'          'day 32'
assert_eq 1 '2023-01-00T12:30:45Z'          'day 0'
assert_eq 1 '2023-01-15T24:00:00Z'          'hour 24'
assert_eq 1 '2023-01-15T12:60:00Z'          'minute 60'
assert_eq 1 '2023-01-15T12:30:61Z'          'second 61'
assert_eq 1 '2023-01-15T12:30:45+24:00'     'offset hour 24'
assert_eq 1 '2023-01-15T12:30:45+02:60'     'offset minute 60'

# --- Invalid: calendar ------------------------------------------------------
assert_eq 1 '2023-02-29T00:00:00Z'          'Feb 29 in non-leap year'
assert_eq 1 '1900-02-29T00:00:00Z'          'Feb 29 in 1900 (not a leap year)'
assert_eq 1 '2023-02-30T00:00:00Z'          'Feb 30'
assert_eq 1 '2023-04-31T00:00:00Z'          'Apr 31'
assert_eq 1 '2023-06-31T00:00:00Z'          'Jun 31'
assert_eq 1 '2023-09-31T00:00:00Z'          'Sep 31'
assert_eq 1 '2023-11-31T00:00:00Z'          'Nov 31'

# --- Summary ----------------------------------------------------------------
printf '1..%d\n' "$tests"
if [[ $failures -ne 0 ]]; then
    printf '# %d of %d tests failed\n' "$failures" "$tests"
    exit 1
fi
printf '# all %d tests passed\n' "$tests"
exit 0
