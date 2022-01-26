#!/bin/bash

# Referenc: https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp
# Path should be checked in the above reference and Dockerfile.
export LD_LIBRARY_PATH=/opt/amazon-kinesis-video-streams-producer-sdk-cpp/open-source/local/lib:$LD_LIBRARY_PATH
export GST_PLUGIN_PATH=/opt/amazon-kinesis-video-streams-producer-sdk-cpp/build:$GST_PLUGIN_PATH
export PATH=/opt/amazon-kinesis-video-streams-producer-sdk-cpp/open-source/local/bin:$PATH

# For debug
export GST_DEBUG=4
export DEBUG_DUMP_FRAME_INFO=1

# The following values shall be passed as environment variables.
# AWS_ACCESS_KEY and AWS_SECRET_KEY are sensitive data. Use AWS Systems Manager Parameter Store.
# The role shall have policy to access Kinesis Video Stream.
export AWS_REGION=$AWS_REGION
export AWS_ACCESS_KEY=$AWS_ACCESS_KEY
export AWS_SECRET_KEY=$AWS_SECRET_KEY

# Reference: https://gstreamer.freedesktop.org/documentation/rtmp/rtmpsrc.html?gi-language=c
/usr/bin/gst-launch-1.0 -v rtmpsrc name=rtmpsrc blocksize=1024 do-timestamp=true location="rtmp://localhost:1935/$1/$2" ! flvdemux name=demux demux.video ! h264parse ! video/x-h264, format=avc,alignment=au ! kvssink log-config=/opt/kvs-log-config stream-name=$2 storage-size=512 aws-region="${AWS_REGION}" access-key="${AWS_ACCESS_KEY}" secret-key="${AWS_SECRET_KEY}" >> /tmp/$1-$2.log &

wait