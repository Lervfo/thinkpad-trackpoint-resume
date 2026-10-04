#!/bin/bash
# Fault injection: all driver operations and waits are mocked; no root needed.
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -r -- "$test_dir"' EXIT

for scenario in healthy missing missing_trackpoint delayed_loss natural_recovery retry_load unload_failure missing_forever load_failure interrupted; do
    status=0
    bash -s -- "$script_dir/trackpoint-resume" "$scenario" "$test_dir/$scenario" <<'TEST' || status=$?
set -euo pipefail
source "$1"
scenario=$2
trace=$3
pad=0 point=0 loads=0 unloads=0 samples=0

case "$scenario" in
    healthy|delayed_loss) pad=1; point=1 ;;
    missing_trackpoint) pad=1 ;;
esac

devices_ready() {
    samples=$((samples + 1))
    if [[ "$scenario" == natural_recovery && "$samples" -ge 2 ]]; then
        pad=1; point=1
    fi
    (( pad && point ))
}
sleep() {
    printf 'sleep %s\n' "$1" >> "$trace"
    if [[ "$scenario" == delayed_loss && "$1" == 3 ]]; then
        pad=0; point=0
    fi
    if [[ "$scenario" == interrupted && "$1" == 4 ]]; then
        kill -TERM "$BASHPID"
    fi
}
timeout() {
    shift 2  # --foreground and timeout duration
    "$@"
}
modprobe() {
    printf 'modprobe %s\n' "$*" >> "$trace"
    if [[ "${1:-}" == -r ]]; then
        unloads=$((unloads + 1))
        pad=0; point=0
        [[ "$scenario" != unload_failure ]]
    else
        loads=$((loads + 1))
        if [[ "$scenario" == load_failure ]] ||
            [[ "$scenario" == retry_load && "$loads" == 1 ]]; then
            return 1
        fi
        if [[ "$scenario" != missing_forever ]]; then
            pad=1; point=1
        fi
        return 0
    fi
}
recover
TEST
    case "$scenario" in
        missing_forever|load_failure) expected_status=1; expected_unloads=2 ;;
        interrupted) expected_status=143; expected_unloads=1 ;;
        healthy|natural_recovery) expected_status=0; expected_unloads=0 ;;
        retry_load) expected_status=0; expected_unloads=2 ;;
        *) expected_status=0; expected_unloads=1 ;;
    esac
    [[ "$status" == "$expected_status" ]] || {
        echo "FAIL $scenario: status $status, expected $expected_status"; exit 1;
    }
    actual_unloads=$(grep -c '^modprobe -r psmouse$' "$test_dir/$scenario" || true)
    [[ "$actual_unloads" == "$expected_unloads" ]] || {
        echo "FAIL $scenario: unloads $actual_unloads, expected $expected_unloads"; exit 1;
    }
    if [[ "$scenario" == interrupted ]]; then
        [[ "$(tail -n 1 "$test_dir/$scenario")" == 'modprobe psmouse' ]]
    fi
    if [[ "$scenario" == load_failure ]]; then
        [[ "$(grep -c '^modprobe psmouse$' "$test_dir/$scenario")" == 3 ]]
    fi
    echo "PASS $scenario"
done

# The pre-sleep path must exit without privilege or device mutation.
bash "$script_dir/trackpoint-resume" pre suspend
echo 'PASS pre-sleep no-op'
