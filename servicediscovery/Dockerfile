FROM python:3

LABEL maintainer="dennis_addo@aol.com"

WORKDIR /srv/service-discovery
ADD sds.py /srv/service-discovery
ADD sds.py /tmp/sdd/

RUN pip install exoscale

ENV EXOSCALE_KEY=""
ENV EXOSCALE_SECRET=""
ENV EXOSCALE_INSTANCEPOOL_ID=""
ENV TARGET_PORT=""
ENV EXOSCALE_ZONE=""

ENTRYPOINT pwd && mv /tmp/sdd/sds.py . && ls -l && python sds.py