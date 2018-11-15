#!/bin/bash
set -e

d=$(dirname $0)
cid=$1
num=$2
uid=$(id -u)
gid=$(id -g)
name="testjob-${num}"
r=0

function docker_exec() {
    set -x
    docker exec --workdir /ci --user ${uid}:${gid} $cid "$@"
    r=$?
    { set +x; } 2>/dev/null
    return $r
}

id=$(docker_exec scontrol show config | grep '^NEXT_JOB_ID' | tr -d ' ' | awk -F= '{print $2}')
docker_exec ./bin/drmaa-run ${d}/${name}.sh &

while true; do
    st=$(docker_exec scontrol --oneliner show job $id | head -1)
    echo "$st"
    case "$(echo $st | sed 's/.*\( \|^\)JobState=\([A-Za-z_][A-Za-z_]*\)\( \|$\).*/\2/p;d')" in
        COMPLETED)
            break;
            ;;
        BOOT_FAIL|CANCELLED|DEADLINE|FAILED|NODE_FAIL|OUT_OF_MEMORY|PREEMPTED|REVOKED|SPECIAL_EXIT|TIMEOUT)
            echo "[slurmctld.log]"
            tail ${d}/slurmctld.log
            echo "[slurmd.log]"
            tail ${d}/slurmd.log
            r=1
            break;
            ;;
        PENDING|CONFIGURING)
            echo "[slurmctld.log]"
            tail ${d}/slurmctld.log
            echo "[slurmd.log]"
            tail ${d}/slurmd.log
            sleep 6
            ;;
        *)
            sleep 2
            ;;
    esac
done

set -x
mv ${d}/.stdout.* ${d}/testjob-${num}.o
mv ${d}/.stderr.* ${d}/testjob-${num}.e
{ set +x; } 2>/dev/null

echo "[test ${num} stdout]"
cat ${d}/testjob-${num}.o
echo "[test ${num} stderr]"
cat ${d}/testjob-${num}.e

exit $r
