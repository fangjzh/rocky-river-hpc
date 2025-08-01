#!/bin/bash

pdsh -w "$1" "shutdown -h now"
