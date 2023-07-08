#!/bin/bash
/usr/bin/killall -0 haproxy || systemctl restart haproxy
