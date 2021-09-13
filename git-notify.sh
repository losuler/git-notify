#!/usr/bin/env bash

set -eu
declare SEND_NOTIFY
# Git commit msg format defaults
declare REPOSITORY="origin/master"
declare FORMAT_NAME="--format=%cn"
declare FORMAT_WHEN="--format=%cr"
declare FORMAT_SUMMARY="--format=%s"
declare FORMAT_BODY="--format=%b"

function distinguish_os {
    # Distinguish between MacOS, Ubuntu, and another Linux
    case "$( uname )" in
      "Darwin")  SEND_NOTIFY="osascript -e ";;
      "Linux")   SEND_NOTIFY="notify-send ";;
      *)         log "Only Mac and Linux platforms are supported." && exit 1;;
    esac
}

function log {
    # Enable verbose logging; adds "[date]: " prefix
    if [ $verbose = true ]; then
        (>&2 echo "[$(date)]: $@")
    else
        echo "$@"
    fi
}

function ps_jobs {
    # Search for current job in running processes
    local curr_comm=$(ps -o command -p "$$" | grep -v COMMAND)
    ps $2 | grep -v "$curr_comm" | grep "$1" | grep -v "grep $1" || true
}

function count {
    # Get count of background jobs
    echo "$bg_jobs" | sed '/^\s*$/d' | wc -l | tr -d ' '
}

function git-curr-branch {
    # Get current git branch; form: "remote"/"branch"
    git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
}

function show_help {
    # Prints help message
    cat << EOF
Usage: git-notify [OPTION]...
Watch git repos and be notified upon detection of new commits.

  -b BRANCH     Specifies the branch to run against (default origin/master)
  -r REPOSITORY Specify what repository to watch (default origin/master)
  -t TIME       Time to wait inbetween checking, in seconds (default 60)
  -c PATH       Path to the config file
  -a            Runs the job in the background (via &)
  -v            Set verbose logging on (adds "[date]: " prefix)
  -l            Find all git-notify background jobs currently running
  -k            Kill all backgrounded git-notify jobs
  -h            Print help and exit
EOF
}

function parse_cmd_args { local args=$@
    # Parses command line options; see help file for options
    local OPTIND opts a
    branch=$(git-curr-branch || echo "origin/master")
    async=false
    refresh_delay=60
    verbose=false

    while getopts ":b:t:r:avlkh" opt; do
        case "$opt" in
        b)  branch="$OPTARG"
            ;;
        t)  refresh_delay="$OPTARG"
            if ! [[ $refresh_delay =~ ^[0-9]+$ ]]; then
                log "Refresh delay must be a number (of seconds)"
                exit 1
            fi
            ;;
        a)  async=true
            ;;
        v)  verbose=true
            ;;
        r)  REPOSITORY="$OPTARG"
            ;;
        c)  CONFIG="$OPTARG"
            ;;
        l)  bg_jobs=$(ps_jobs "$0" "-eaf")
            bg_count=$(count "$bg_jobs")
            log "Running background jobs: $bg_count"
            if [ $bg_count -gt 0 ]; then
                # Print ps column names header
                ps -fp 0 | head -n 1
                echo "$bg_jobs"
            fi
            exit 0
            ;;
        k)  curr_comm=$(ps -o command -p "$$" | grep -v COMMAND)
            bg_jobs=$(ps_jobs "$0" "-eao pid,command" | cut -f 1 -d ' ')
            bg_count=$(count "$bg_jobs")
            if [ $bg_count -eq 0 ]; then
                log "No jobs running!"
            else
                log -n "Killing $bg_count jobs: "
                log $bg_jobs
                kill $bg_jobs
                log "Success!"
            fi
            exit 0
            ;;
        h)  show_help
            exit 1
            ;;
        :)  log "Required argument for option $OPTARG"
            exit 1
            ;;
        ?)  log "Unrecognized option $OPTARG"
            exit 1
            ;;
        esac
    done
    shift $((OPTIND-1))
}

function run {
    # Run function
    latest_revision="none"
    # Loop forever, need to kill the process explicitly to stop.
    while [ 1 ]; do
        # Get the latest revision SHA.
        current_revision=$(git rev-parse $REPOSITORY)

        # If we haven't seen that one yet, then we know there's new stuff.
        if [ $latest_revision != $current_revision ]; then
            log "Changed! New revision: $current_revision"
            # Mark the newest revision as seen.
            latest_revision=$current_revision

            # Extract the details from the log.
            commit_name=`git log -1 $FORMAT_NAME $latest_revision`
            commit_when=`git log -1 $FORMAT_WHEN $latest_revision`
            commit_summary=`git log -1 $FORMAT_SUMMARY $latest_revision`
            commit_body=`git log -1 $FORMAT_BODY $latest_revision`

            # Notify the user of the commit.
            summary="$commit_name committed to $REPOSITORY $commit_when!"
            body="$commit_summary\n\n$commit_body"

            if [ $CONFIG != "" ]; then
                source $CONFIG
                markdown_body="**$summary**\n$commit_summary\n$commit_body"
                html_body="<strong>$summary</strong></br>$commit_summary</br>$commit_body"
                path="_matrix/client/r0/rooms/$MATRIX_ROOM:$MATRIX_DOMAIN/send/m.room.message"
                query="?access_token=$MATRIX_TOKEN"

                curl -X PUT --header 'Content-Type: application/json' \
                    --header 'Accept: application/json' \
                    -d "{\"msgtype\":\"m.notice\",
                    \"body\":\"$markdown_body\",
                    \"format\":\"org.matrix.custom.html\",
                    \"formatted_body\":\"$html_body\"}" \
                    "https://$MATRIX_DOMAIN/$path/$(date +%s)$query"
            elif [ "`uname`" == "Darwin" ]; then
                command="osascript -e 'display notification \"$body\" with title \"$summary\"'"
                eval $command
            else
                `notify-send "$summary" "$body"`
            fi
        fi
        sleep "$refresh_delay"
    done
}

function main {
    # Main function; most of logic driven by run()
    parse_cmd_args "$@"
    log "Watching branch $branch..."

    # Test git repository and start execution
    if !(git rev-parse --git-dir > /dev/null 2>&1); then
        log "Error: not ran against a git repository."
        exit 1
    else
        if [ $async = true ]; then
            run &
            log "Started background job with PID $!"
        else
            (run)
        fi
    fi
}

main "$@"
