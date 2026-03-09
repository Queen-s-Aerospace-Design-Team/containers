# --------------------------
# Base image & environment
# --------------------------
    
FROM ros:humble-ros-base

LABEL org.opencontainers.image.source="https://github.com/Queen-s-Aerospace-Design-Team/containers"

ENV ROS_DISTRO=humble \
    DEBIAN_FRONTEND=noninteractive \
    HOME_DIR=/home/qadt-deployment \
    USER=qadt-deployment

SHELL ["/bin/bash", "-c"]

# --------------------------
# System Dependencies
# --------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    python3-colcon-common-extensions \
    python3-pip \
    python3-rosdep \
    software-properties-common \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository universe \
    && export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" && \
    dpkg -i /tmp/ros2-apt-source.deb && \
    apt-get update

RUN rosdep init || true

# --------------------------
# Workspace and Development Dependencies
# --------------------------

WORKDIR ${HOME_DIR}

RUN git clone --branch v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git --depth 1 \
    && cmake -S Micro-XRCE-DDS-Agent -B Micro-XRCE-DDS-Agent/build \
    && cmake --build Micro-XRCE-DDS-Agent/build -j $(nproc) \
    && cmake --install Micro-XRCE-DDS-Agent/build \
    && ldconfig \
	&& rm -rf Micro-XRCE-DDS-Agent/build

# Clone repo
ARG GIT_REF=main
RUN git clone --recurse-submodules https://github.com/Queen-s-Aerospace-Design-Team/AEAC2026.git \
    && cd ${HOME_DIR}/AEAC2026 \
    && git checkout "$GIT_REF" \
    && git submodule update --init --recursive

# Enter AEAC2026/ros_ws (where our ROS workspace is)
WORKDIR ${HOME_DIR}/AEAC2026/ros_ws

# Run rosdep
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -y --rosdistro=${ROS_DISTRO}

# Build but place outputs in home
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --symlink-install --base-paths src 

WORKDIR ${HOME_DIR}

# Python dependencies for google drive uploading. After all pip installs, remove pip cache
RUN pip install --no-cache-dir google-auth google-api-python-client \
    && pip cache purge

# Copy necessary files from the dockerfile's directory into the container
COPY dotfiles/.bashrc \
	dotfiles/.profile \
	dotfiles/.tmux.conf \
	dotfiles/.zshrc \
	entrypoint.sh \
	./

# Add new user with sudo access without needing password
RUN useradd -ms /bin/bash ${USER} && \
    echo "${USER}:aero" | chpasswd && \
    usermod -aG sudo ${USER} \
	&& echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}

# Make user 'qadt' own all files in home directory
RUN chown -R ${USER}:${USER} ${HOME_DIR} \
	&& chmod +x ${HOME_DIR}/entrypoint.sh 

# Finalize
USER ${USER}
ENTRYPOINT [ "/home/qadt-deployment/entrypoint.sh" ]

# We do not launch with a command as it could cause crashes. 
# Instead, it is provided under the compose profile we launch into it with.