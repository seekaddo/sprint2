FROM python:3

LABEL maintainer="dennis_addo@aol.com"

RUN mkdir -p /srv/service-discovery
WORKDIR /tmp/service-discovery
COPY sds.py /tmp/service-discovery


ENV EXOSCALE_KEY=""
ENV EXOSCALE_SECRET=""
ENV EXOSCALE_INSTANCEPOOL_ID=""
ENV TARGET_PORT=""
ENV EXOSCALE_ZONE=""

RUN pip install exoscale

#ENTRYPOINT pwd && mv /tmp/sdd/sds.py . && ls -l && python sds.py
ENTRYPOINT ["python","sds.py"]