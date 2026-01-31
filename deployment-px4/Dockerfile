# --------------------------
# Base image & environment
# --------------------------

FROM osrf/ros:humble-ros-base as builder

ARG ROS_DISTRO=humble

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    python3-colcon-common-extensions \
    python3-pip \
    python3-rosdep \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create a ROS workspace
WORKDIR /ros_ws/src

# Copy your local source code into the container
COPY ./src .

# Install dependencies and build the workspace
WORKDIR /ros_ws
RUN rosdep install --from-paths src --ignore-src -y
RUN colcon build --symlink-install

# --- Stage 2: Minimal Runtime Environment ---
FROM osrf/ros:humble-ros-base

ARG ROS_DISTRO=humble

# Copy built artifacts from the builder stage
COPY --from=builder /ros_ws/install /opt/ros/$ROS_DISTRO/install
COPY --from=builder /ros_ws/src /opt/ros/$ROS_DISTRO/src

# Set the entrypoint script provided by the base image
ENTRYPOINT ["/usr/bin/ros2", "launch"]
CMD ["your_package_name", "your_launch_file.launch.py"]
