# ==========================================
FROM ros:humble-ros-base AS builder

# Set shell to bash for better command handling
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    python3-colcon-common-extensions \
    python3-pip \
    python3-rosdep \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

#    Required for the drone to talk to the Flight Controller
WORKDIR /tmp
RUN git clone --branch v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git --depth 1 \
    && cmake -S Micro-XRCE-DDS-Agent -B Micro-XRCE-DDS-Agent/build \
    && cmake --build Micro-XRCE-DDS-Agent/build -j $(nproc) \
    && cmake --install Micro-XRCE-DDS-Agent/build

# Build Custom ROS Workspace
WORKDIR /ros_ws
COPY ./src ./src

#    Initialize rosdep and install build dependencies
RUN (rosdep init || echo "rosdep already initialized") && rosdep update \
    && rosdep install --from-paths src --ignore-src -y

#    Build the workspace
RUN colcon build --symlink-install --base-paths src --install-base /opt/qadt_ws

# ==========================================
FROM ros:humble-ros-base

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME_DIR=/home/qadt

RUN useradd -ms /bin/bash qadt && \
    echo "qadt:aero" | chpasswd && \
    usermod -aG sudo qadt

# Install Runtime Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-rosdep \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

#    Initialize rosdep for the runtime stage
RUN rosdep init || echo "rosdep already initialized" && rosdep update

#    Copy source temporarily so rosdep knows what to install
COPY --from=builder /ros_ws/src /tmp/src

#    Install ONLY execution dependencies to keep image small
RUN rosdep install --from-paths /tmp/src --ignore-src -y --dependency-types=exec \
    && rm -rf /tmp/src \
    && rm -rf /var/lib/apt/lists/*

#    Micro-XRCE-DDS binaries and libraries
COPY --from=builder /usr/local/bin/MicroXRCEAgent /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
RUN ldconfig

#    Your ROS Workspace
COPY --chown=qadt:qadt --from=builder /opt/qadt_ws /opt/qadt_ws

#    Sources ROS and your workspace automatically
RUN echo -e '#!/bin/bash \n\
source /opt/ros/humble/setup.bash \n\
if [ -f /opt/qadt_ws/setup.bash ]; then \n\
  source /opt/qadt_ws/setup.bash \n\
fi \n\
exec "$@"' > /entrypoint.sh && chmod +x /entrypoint.sh

# Finalize
USER qadt
WORKDIR /home/qadt
ENTRYPOINT ["/entrypoint.sh"]

# Default command: Launch the MicroXRCEAgent
CMD ["MicroXRCEAgent", "udp4", "-p", "8888"]