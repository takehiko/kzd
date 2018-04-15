FROM ubuntu:16.04
MAINTAINER takehiko

RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y locales locales-all && \
  apt-get install -y git ruby imagemagick && \
  rm -rf /var/lib/apt/lists/* && \
  gem install rubyzip

ENV LANG ja_JP.UTF-8
WORKDIR /root

RUN \
  https://github.com/takehiko/kzd.git && \
  sed -e "s/..\\/lib/kzd\\/lib/" kzd/sample/hideyoshi.rb > hideyoshi.rb && \
  chmod +x hideyoshi.rb

CMD ["bash"]

# docker build -t kzd .
# docker run -it --rm kzd
# docker run -it --rm -v $(pwd):/h kzd ./hideyoshi.rb /h
