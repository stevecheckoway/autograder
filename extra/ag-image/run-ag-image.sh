#!/bin/bash

if [ $EUID -ne 0 ]; then
	echo "$0 must be run as root" >&2
	exit 1
fi

if [ $# -ne 2 ]; then
	echo "Usage: $0 WORKSPACE SCRIPT_PATH" >&2
	exit 1
fi

if echo "$1" | egrep '\.\.|/'; then
	echo "$0: Workspace '$1' is invalid" >&2
	exit 1
fi

if echo "$2" | grep '\.\.'; then
	echo "$0: Script path '$2' is invalid" >&2
	exit 1
fi

ws="/var/lib/autograder/autograder/workspace/$1"
script="$2"

if [ ! -d "$ws" ]; then
	echo "$0: No such directory '$ws'" >&2
	exit 1
fi

if [ ! -f "$ws/$script" ]; then
	echo "$0: No such file '$ws/$script'" >&2
	exit 1
fi

# Bind a new directory with uid 1000 for the gader user in docker.
umask 0007
tmpdir=$(mktemp -d)

cleanup() {
	umount -f "$tmpdir"
	rmdir "$tmpdir"
}
trap cleanup EXIT

grader_uid=999
grader_gid=999
user=$(id -un $UID)
group=$(id -gn $UID)

if ! bindfs 	-u "$grader_uid" \
		-g "$grader_gid" \
		--create-for-user="$user" \
		--create-for-group="$group" \
		"$ws" "$tmpdir"; then
	echo "$0: Failed to bind '$ws' to '$tmpdir'" 2>&1
	exit 1
fi

docker run \
	-t \
	-v "$tmpdir":/home/grader:Z \
	--rm \
	--read-only \
	--ulimit nproc=50 \
	ag-image \
	/bin/bash "$script"
