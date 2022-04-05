#!/bin/bash

docker_process=docker container ls -q
docker kill $docker_process
