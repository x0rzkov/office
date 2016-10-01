FROM blacktop/yara

MAINTAINER blacktop, https://github.com/blacktop

ENV OLEDUMP_URL didierstevens.com/files/software/oledump_V0_0_25.zip
ENV RTFDUMP_URL didierstevens.com/files/software/rtfdump_V0_0_4.zip

COPY . /go/src/github.com/maliceio/malice-office
RUN apk-install python
RUN apk-install -t build-deps go \
                              git \
                              curl \
                              unzip \
                              py-pip \
                              mercurial \
                              build-base \
                              python-dev \
                              py-setuptools \
  && set -x \
  && echo "Install oletools..." \
  && export PIP_NO_CACHE_DIR=off \
  && export PIP_DISABLE_PIP_VERSION_CHECK=on \
  && pip install --upgrade pip wheel \
  && pip install https://github.com/decalage2/olefile/zipball/master \
  && pip install https://github.com/decalage2/oletools/zipball/master \
  && echo "Fixing error in oledir.py" \
  && sed -i 's/from thirdparty.colorclass import colorclass/from thirdparty.colorclass import color/' /usr/lib/python2.7/site-packages/oletools/oledir.py \
  && chmod +x /usr/lib/python2.7/site-packages/oletools/*.py \
  && ln -s /usr/lib/python2.7/site-packages/oletools/ezhexviewer.py /usr/local/bin/ezhexviewer \
  && ln -s /usr/lib/python2.7/site-packages/oletools/mraptor.py /usr/local/bin/mraptor \
  && ln -s /usr/lib/python2.7/site-packages/oletools/olebrowse.py /usr/local/bin/olebrowse \
  && ln -s /usr/lib/python2.7/site-packages/oletools/oledir.py /usr/local/bin/oledir \
  && ln -s /usr/lib/python2.7/site-packages/oletools/oleid.py /usr/local/bin/oleid \
  && ln -s /usr/lib/python2.7/site-packages/oletools/olemap.py /usr/local/bin/olemap \
  && ln -s /usr/lib/python2.7/site-packages/oletools/olemeta.py /usr/local/bin/olemeta \
  && ln -s /usr/lib/python2.7/site-packages/oletools/oleobj.py /usr/local/bin/oleobj \
  && ln -s /usr/lib/python2.7/site-packages/oletools/oletimes.py /usr/local/bin/oletimes \
  && ln -s /usr/lib/python2.7/site-packages/oletools/olevba.py /usr/local/bin/olevba \
  && ln -s /usr/lib/python2.7/site-packages/oletools/ppt_parser.py /usr/local/bin/ppt_parser \
  && ln -s /usr/lib/python2.7/site-packages/oletools/pyxswf.py /usr/local/bin/pyxswf \
  && ln -s /usr/lib/python2.7/site-packages/oletools/rtfobj.py /usr/local/bin/rtfobj \
  && echo "Install oledump..." \
  && curl -Ls https://${OLEDUMP_URL} > /tmp/oledump.zip \
  && cd /tmp \
  && mkdir -p /opt/oledump \
  && unzip oledump.zip -d /opt/oledump \
  && chmod +x /opt/oledump/oledump.py  \
  && ln -s /opt/oledump/oledump.py /usr/local/bin/oledump \
  && echo "Install rtfdump..." \
  && curl -Ls https://${RTFDUMP_URL} > /tmp/rtfdump.zip \
  && mkdir -p /opt/rtfdump \
  && unzip rtfdump.zip -d /opt/rtfdump \
  && chmod +x /opt/rtfdump/rtfdump.py  \
  && ln -s /opt/rtfdump/rtfdump.py /usr/local/bin/rtfdump \
  && echo "Install ViperMonkey..." \
  && curl -Ls https://github.com/decalage2/ViperMonkey/archive/master.zip > /tmp/ViperMonkey.zip \
  && mkdir -p /opt/vipermonkey \
  && unzip ViperMonkey.zip \
  && mv ViperMonkey-master/vipermonkey/ /opt/vipermonkey \
  && cd /opt/vipermonkey \
  && pip install prettytable colorlog colorama pyparsing \
  && chmod +x vmonkey.py vbashell.py \
  && ln -s /opt/vipermonkey/vmonkey.py /usr/local/bin/vmonkey \
  && ln -s /opt/vipermonkey/vbashell.py /usr/local/bin/vbashell \
  && echo "Building scan Go binary..." \
  && cd /go/src/github.com/maliceio/malice-office \
  && export GOPATH=/go \
  && go version \
  && go get \
  && go build -ldflags "-X main.Version=$(cat VERSION) -X main.BuildTime=$(date -u +%Y%m%d)" -o /bin/scan \
  && echo "Clean unnecessary files..." \
  && cd /usr/lib/python2.7/site-packages/oletools \
  && find . ! -name '*.py*' -type f -exec rm -f {} + && rm -rf doc \
  && cd /usr/lib/python2.7/site-packages/olefile \
  && find . ! -name '*.py*' -type f -exec rm -f {} + && rm -rf doc \
  && rm -rf /go /tmp/* \
  && apk del --purge build-deps

WORKDIR /malware

ENTRYPOINT ["/bin/scan"]

CMD ["--help"]
