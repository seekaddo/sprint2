FROM python:3

LABEL maintainer="dennis_addo@aol.com"

WORKDIR /srv/service-discovery
ADD sds.py /srv/service-discovery
ADD sds.py /tmp/sdd/
ADD startup.sh /tmp/sdd/

RUN chmod +x /tmp/sdd/startup.sh

RUN pip install exoscale

ENV EXOSCALE_KEY=""
ENV EXOSCALE_SECRET=""
ENV EXOSCALE_INSTANCEPOOL_ID=""
ENV TARGET_PORT=""
ENV EXOSCALE_ZONE=""

#ENTRYPOINT pwd && mv /tmp/sdd/sds.py . && ls -l && python sds.py
ENTRYPOINT ["/tmp/sdd/startup.sh"]