FROM ubuntu:latest

COPY . /app

# in macOS this is included in developer tools 
RUN apt-get update && apt-get install -y curl git

RUN bash /app/install.sh

