# ######### Build Image
FROM swift:5.5-focal AS builder

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
	&& apt-get -q update \
	&& apt-get -q dist-upgrade -y \
	&& apt-get install -y zlib1g-dev \
	&& rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused as long as the
# Package.swift/Package.resolved files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build everything, with optimizations
RUN swift build --disable-automatic-resolution -c release -Xswiftc -D -Xswiftc TERMINAL_EMOJI

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/locmapper" ./


# ######### Run Image
FROM swift:5.5-focal-slim

ARG LOCMAPPER_USER_ID=1000

# Make sure all system packages are up to date.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
	apt-get -q update && apt-get -q dist-upgrade -y && rm -r /var/lib/apt/lists/*

# Create a locmapper user and group with /locmapper as its home directory
RUN useradd --uid "$LOCMAPPER_USER_ID" --no-user-group --create-home --system --skel /dev/null --home-dir /locmapper locmapper

# Switch to the new home directory
WORKDIR /locmapper

# Copy built executable and any staged resources from builder
COPY --from=builder --chown=locmapper:locmapper /staging /locmapper

# Ensure all further commands run as the vapor user
USER locmapper:users

ENTRYPOINT ["./locmapper"]
CMD ["--help"]
