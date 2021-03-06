#
# @name: Addo Kwame Dennis
# @file: sds.py --> Service discovery script (sds)
# @brief: simple script leveraging the exoscale python api for itrating with the exoscale compute
#
#
#
import exoscale
import os
import json
import pathlib
import time
import signal
import logging as pylogger
import sys
import os.path

standPath = "/srv/service-discovery"


def getConfigPath():
    if not os.path.exists(standPath):
        pylogger.error("Standard dir not created by docker.")
        # It will be nice to recreate the directory but we are confidently stubborn to trust docker
        return False
    return True


absolutePath = pathlib.Path(os.path.realpath(__file__)).parent
service_config_file = os.path.join(standPath if getConfigPath() else absolutePath, 'config.json')
logpath = os.path.join(standPath if getConfigPath() else absolutePath, 'sds.log')
pylogger.basicConfig(filename=logpath, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                     level=pylogger.ERROR | pylogger.INFO | pylogger.WARNING)


def Clean_up(xSignum, xFrame):
    pylogger.info("Signal received shutdown now signal: ", xSignum)
    exit(0)

# the container can send only Termin signal that is docker stop
signal.signal(signal.SIGTERM, Clean_up)  # Used by this script


def queryInstances(api_key, api_secret, exoscale_instancepool_id, target_port, exoscale_zone):
    exo = exoscale.Exoscale(api_key=api_key, api_secret=api_secret)
    zone = exo.compute.get_zone(name=exoscale_zone)
    if not zone:
        pylogger.error("Invalid Zone -- cannot be empty")
        sys.exit(1)

    targetList = []
    for instance in exo.compute.list_instances(zone):
        try:
            instance_pool = instance.instance_pool
            if instance_pool and exoscale_instancepool_id == instance_pool.id:
                target = {'targets': [instance.ipv4_address + ':' + target_port]}
                pylogger.info("Targets: {0}".format(target))
                targetList.append(target)
        except Exception:
            pylogger.error("Something went wrong", exc_info=True)

    pylogger.info("Write targets {0} into {1}".format(targetList, service_config_file))
    with open(service_config_file, 'w') as outfile:
        pylogger.info("Overwrite the config.json file with content: {0}".format(outfile))
        json.dump(targetList, outfile)


def get_values_from_environment():
    pylogger.debug("Read the environment variables")

    api_key = None
    api_secret = None
    exoscale_instancepool_id = None
    target_port = None
    exoscale_zone = None

    for item, value in os.environ.items():
        if item == 'EXOSCALE_KEY':
            api_key = value
        elif item == 'EXOSCALE_SECRET':
            api_secret = value
        elif item == 'EXOSCALE_INSTANCEPOOL_ID':
            exoscale_instancepool_id = value
        elif item == 'TARGET_PORT':
            target_port = value
        elif item == 'EXOSCALE_ZONE':
            exoscale_zone = value

    if not api_key or not api_secret or not exoscale_instancepool_id or not target_port or not exoscale_zone:
        pylogger.error("Invalid input --> empty api_key:{0}, api_secret:{1}, exoscale_instancepool_id:{2}, "
                       "target_port:{3}, exoscale_zone:{4}".format(api_key, api_secret, exoscale_instancepool_id,
                                                                   target_port, exoscale_zone))
        sys.exit(1)

    return api_key, api_secret, exoscale_instancepool_id, target_port, exoscale_zone


if __name__ == '__main__':
    pylogger.info("------Start-------------")

    pylogger.info("absolutePath:{0} -- wtf log path--- logpath: {1} service_config_file: {2}".format(
        absolutePath, logpath, service_config_file))
    api_key, api_secret, exoscale_instancepool_id, target_port, exoscale_zone = get_values_from_environment()

    while True:
        try:
            pylogger.info("queryInstances with key:{0} secret: {1}, instapollID: {2}, port:{3}, zone:{4}".format(
                api_key, api_secret, exoscale_instancepool_id, target_port, exoscale_zone))

            queryInstances(api_key, api_secret, exoscale_instancepool_id, target_port, exoscale_zone)
            time.sleep(5)
            pylogger.info("Pulling for the instance list and updating the config file")
        except Exception:
            pylogger.error("You hit a bad rock", exc_info=True)
