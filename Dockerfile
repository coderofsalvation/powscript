FROM quay.io/travisci/travis-ruby:latest

WORKDIR /home/travis/
RUN mkdir powscript
COPY . ./powscript
USER travis
WORKDIR /home/travis/powscript
RUN {\
 {\
 linenum=0;\
 while IFS="" read line; do\
 linenum=$(($linenum+1));\
 echo "$linenum|  $line";\
 done;\
 } < "./powscript";\
}
CMD {\
 ./.tools/runtests;\
}
