# --------------------------
# Base image & environment
# --------------------------

FROM osrf/ros:humble-desktop
	
LABEL org.opencontainers.image.source="https://github.com/Queen-s-Aerospace-Design-Team/containers"

ENV ROS_DISTRO=humble \
	DEBIAN_FRONTEND=noninteractive  \
	DOCKER_BUILDKIT=1 \
	HOME_DIR=/home/qadt

SHELL ["/bin/bash", "-c"] 

# --------------------------
# System Dependencies
# --------------------------

# Update and install necessary dependencies
RUN apt-get update && apt-get install -y \
    wget \
	curl \
    astyle \
	build-essential \
	ccache \
	cmake \
	cppcheck \
	file \
	g++ \
	gcc \
	gdb \
	git \
	clang \
    clang-format \
	lcov \
	libssl-dev \
	libxml2-dev \
	libxml2-utils \
	make \
	ninja-build \
	python3 \
	python3-dev \
	python3-pip \
	python3-setuptools \
	python3-wheel \
	rsync \
	shellcheck \
	vim \
    neovim \
	tmux \
    # Extra ros installs
    '~nros-humble-rqt*' \
	ros-humble-turtlesim \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-ros-gz \
    ros-humble-topic-tools \
    mesa-utils \
    libgl1 \
    libglx-mesa0 \
    && rm -rf /var/lib/apt/lists/*

# --------------------------
# Workspace and Development Dependencies
# --------------------------

# Create your workspace here
WORKDIR $HOME_DIR

# Clone MicroDDS. Adapted from https://docs.px4.io/main/en/ros2/user_guide
# NOTE: Used to be v2.4.2 but updating to v2.4.3 as v2.4.2 had issues with docker build.
# Build MicroDDS using cmake via the ninja-build generator. '-j $(nproc)' will use all processors to speed up build times.
RUN git clone --branch v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git --depth 1 \
	&& cmake -S Micro-XRCE-DDS-Agent -B Micro-XRCE-DDS-Agent/build -G "Ninja" \
    && cmake --build Micro-XRCE-DDS-Agent/build -j $(nproc) \
    && cmake --install Micro-XRCE-DDS-Agent/build \
    && ldconfig \
	&& rm -rf Micro-XRCE-DDS-Agent/build

# Python dependencies in requirements.txt
COPY px4_ubuntu.sh requirements.txt ./
RUN chmod +x px4_ubuntu.sh && ./px4_ubuntu.sh

# Run the setup and build for PX4
RUN git clone --single-branch --branch v1.16.1 https://github.com/PX4/PX4-Autopilot.git --recursive --depth 1 \
	&& make -C PX4-Autopilot

# Python dependencies for google drive uploading. After all pip installs, remove pip cache
RUN pip install --no-cache-dir google-auth google-api-python-client \
    && pip cache purge

# --------------------------
# Entrypoint and User
# --------------------------

# Add new user 'qadt'
RUN useradd -ms /bin/bash qadt && \
    echo "qadt:aero" | chpasswd && \
    usermod -aG sudo qadt \
	# Uncomment if you want sudo access without a password
	&& echo "qadt ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/qadt \
    && chmod 0440 /etc/sudoers.d/qadt
	
# Copy necessary files from the dockerfile's directory into the container
COPY dotfiles/.bashrc \
	dotfiles/.profile \
	dotfiles/.tmux.conf \
	dotfiles/.zshrc \
	entrypoint.sh \
	./

# Make user 'qadt' own all files in home directory
RUN chown -R qadt:qadt ${HOME_DIR} \
	&& chmod +x ${HOME_DIR}/entrypoint.sh 

# Switch to user and run entry point
USER qadt
ENTRYPOINT [ "/home/qadt/entrypoint.sh" ]
CMD [ "bash" ]
