FROM ubuntu:22.04

# Set environment variables
ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter \
    PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:${PATH}" \
    FLUTTER_DISABLE_ANALYTICS=true \
    DART_DISABLE_ANALYTICS=true

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    curl \
    git \
    unzip \
    xz-utils \
    lib32stdc++6 \
    lib32z1 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Download and install Android SDK
RUN mkdir -p ${ANDROID_SDK_ROOT} && \
    cd ${ANDROID_SDK_ROOT} && \
    curl -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip -q cmdline-tools.zip && \
    rm cmdline-tools.zip && \
    mkdir -p cmdline-tools/latest && \
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true

# Accept Android licenses and install required SDK components
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" \
    "platforms;android-35" \
    "platforms;android-34" \
    "build-tools;35.0.0" \
    "build-tools;34.0.0" \
    "ndk;27.0.12077973"

# Download and install Flutter
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git ${FLUTTER_HOME}

# Run flutter doctor to complete setup
RUN flutter doctor

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock* ./

# Get dependencies
RUN flutter pub get

# Copy entire project
COPY . .

# Build APK (debug by default, can be overridden)
CMD ["flutter", "build", "apk", "--debug"]
