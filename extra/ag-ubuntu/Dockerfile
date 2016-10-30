FROM ubuntu:13.10
MAINTAINER Stephen Checkoway <sfc@uic.edu>

# Fix apt paths
RUN sed -r -i -e 's,://(archive\.ubuntu\.com|security\.ubuntu\.com),://old-releases.ubuntu.com,g' /etc/apt/sources.list

# Install some packages.
RUN dpkg --add-architecture i386 && \
	apt-get update && \
	apt-get install -y \
		build-essential \
		gcc-multilib \
		g++-multilib \
		make \
		python && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Create a group
RUN groupadd \
	--system \
	--gid 999 \
	grader

# Create a user in the newly created group
RUN useradd \
	--system \
	--uid 999 \
	--gid 999 \
	--no-user-group \
	--home /home/grader \
	--shell /bin/bash \
	grader

USER grader
WORKDIR /home/grader
