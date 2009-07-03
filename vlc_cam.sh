#!/bin/bash

vlc v4l2:// :v4l2-vdev="/dev/video0" :v4l2-adev="/dev/audio2" :v4l2-norm=3 :v4l2-frequency=-1 :v4l2-caching=300 :v4l2-chroma="" :v4l2-fps=-1.000000 :v4l2-samplerate=44100 :v4l2-channel=0 :v4l2-tuner=-1 :v4l2-audio=-1 :v4l-stereo :v4l2-width=1028 :v4l2-height=760 :v4l2-brightness=-1 :v4l2-colour=-1 :v4l2-hue=-1 :v4l2-contrast=-1 :no-v4l2-mjpeg :v4l2-decimation=1 :v4l2-quality=100