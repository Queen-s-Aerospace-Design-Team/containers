# --------------------------
# Base image & environment
# --------------------------
    
FROM ros:humble-ros-base

LABEL org.opencontainers.image.source="https://github.com/Queen-s-Aerospace-Design-Team/containers"

ENV ROS_DISTRO=humble \
    DEBIAN_FRONTEND=noninteractive \
    HOME_DIR=/home/qadt-deploy \
    USERNAME=qadt-deploy

SHELL ["/bin/bash", "-c"]

# --------------------------
# System Dependencies
# --------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    python3-colcon-common-extensions \
    python3-pip \
    software-properties-common \
    curl \
    wget \
    ca-certificates
    
# If the rosdep source file doesn't exist, then rosdep init
RUN if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then rosdep init; fi \
    && rosdep update --rosdistro "${ROS_DISTRO}"
    
# --------------------------
# Workspace and Development Dependencies
# --------------------------

WORKDIR ${HOME_DIR}

# Clone MicroDDS. Adapted from https://docs.px4.io/main/en/ros2/user_guide
# NOTE: Used to be v2.4.2 but updating to v2.4.3 as v2.4.2 had issues with docker build.
RUN git clone --branch v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git --depth 1 \
    && cmake -S Micro-XRCE-DDS-Agent -B Micro-XRCE-DDS-Agent/build \
    && cmake --build Micro-XRCE-DDS-Agent/build -j $(nproc) \
    && cmake --install Micro-XRCE-DDS-Agent/build \
    && ldconfig \
	&& rm -rf Micro-XRCE-DDS-Agent

# Python dependencies for google drive uploading and Jetson GPIO
RUN pip install --no-cache-dir \
    google-auth \
    google-auth-oauthlib \
    google-api-python-client \
    Jetson.GPIO

# -- Repo Clone & Build --

# Clone repo and run rosdep install
RUN git clone --branch main --depth 1 --recurse-submodules https://github.com/Queen-s-Aerospace-Design-Team/AEAC2026.git \
    && apt-get update \
    && cd ${HOME_DIR}/AEAC2026/ros_ws \
    && source /opt/ros/${ROS_DISTRO}/setup.bash \
    && rosdep install --from-paths src --ignore-src -y --rosdistro=${ROS_DISTRO} \
    && rm -rf /var/lib/apt/lists/*

# Run colcon build
RUN cd ${HOME_DIR}/AEAC2026/ros_ws \
    && source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --symlink-install --base-paths src

# Copy necessary files from the dockerfile's directory into the container
COPY dotfiles/.bashrc \
	dotfiles/.profile \
	dotfiles/.tmux.conf \
	dotfiles/.zshrc \
	entrypoint.sh \
	./

# Add new user with sudo access without needing password
RUN useradd -ms /bin/bash ${USERNAME} && \
    echo "${USERNAME}:aero" | chpasswd && \
    usermod -aG sudo ${USERNAME} \
	&& echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Make user own all files in home directory
RUN chown -R ${USERNAME}:${USERNAME} ${HOME_DIR} \
	&& chmod +x ${HOME_DIR}/entrypoint.sh 

# Finalize
USER ${USERNAME}
ENTRYPOINT [ "/home/qadt-deploy/entrypoint.sh" ]

# We do not launch with a command as it could cause crashes. 
# Instead, it is provided under the compose profile we launch into it with.
