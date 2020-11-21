variable "exoscale_key" { type = string  }
variable "exoscale_secret" { type = string }

terraform {
  required_providers {
    exoscale = {
      source = "terraform-providers/exoscale"
    }
  }
}

provider "exoscale" {
  key = var.exoscale_key
  secret = var.exoscale_secret
}

locals {
  zone = "at-vie-1"
  # instnace in Vienna for low latency
}

/*variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = number
  default = 8080
}*/

output "vm_list" {
  value =  exoscale_instance_pool.compute_pool.virtual_machines
  description = "The list of Instance Pool members (Compute instance names)."
}


# Data section
data "exoscale_compute_template" "computeTemp" {
  zone = local.zone
  name = "Linux Ubuntu 20.04 LTS 64-bit"
}



resource "exoscale_security_group" "secgroup1" {
  name = "secgroup"
}

resource "exoscale_security_group_rule" "http" {
  security_group_id = exoscale_security_group.secgroup1.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 80
  end_port          = 80
  description = "Managed by Only Terraform!"
}

## this is for the one extra instance with Prometheus running on it on port 9090
resource "exoscale_security_group_rule" "promethes" {
  security_group_id = exoscale_security_group.secgroup1.id
  type = "INGRESS"
  cidr = "0.0.0.0/0"
  start_port = 9090
  end_port = 9090
  protocol = "TCP"
  description = "Managed by Only Terraform!"
}

resource "exoscale_security_group_rule" "node_exporter" {
  security_group_id = exoscale_security_group.secgroup1.id
  type = "INGRESS"
  protocol = "tcp"
  cidr = "0.0.0.0/0"
  start_port = 9100
  end_port = 9100
  description = "Managed by Only Terraform!"
}



resource "exoscale_nlb" "nlbConfig" {
  name        = "website-nlb"
  description = "A simple NLB service"
  zone        = local.zone
}

resource "exoscale_nlb_service" "nlb_service_sprint2" {
  zone             = exoscale_nlb.nlbConfig.zone
  name             = "NLB-web"
  description      = "Website over HTTP"
  nlb_id           = exoscale_nlb.nlbConfig.id
  instance_pool_id = exoscale_instance_pool.compute_pool.id
  protocol         = "tcp"
  port             = 80
  target_port      = 80
  strategy         = "round-robin"

  healthcheck {
    port     = 80
    mode     = "http"
    uri      = "/health"
    interval = 10
    timeout  = 10
    retries  = 1
  }
}

# --------------------------------------------------------------------
# ----------------------------Rescource section -----------------------
resource "exoscale_instance_pool" "compute_pool" {
  name               = "FH-CC Sprint 2"
  description        = "Instnace pool for the sprint 2 task"
  template_id        = data.exoscale_compute_template.computeTemp.id
  service_offering   = "micro"
  size               = 2
  disk_size          = 10
  zone               = local.zone
  security_group_ids = [exoscale_security_group.secgroup1.id]
  user_data          = <<EOF
#!/bin/bash

set -e

# region Install Docker
apt-get update
apt-get install -y curl
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Run the load generator
docker run -d \
  --restart=always \
  -p 80:8080 \
  janoszen/http-load-generator:1.0.1

##Deploy the node-exporter via docker
sudo docker run -d -p 9100:9100 \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter \
  --path.rootfs=/host
EOF

}


resource "exoscale_compute" "prometheus" {
  zone         = local.zone
  display_name = "prometheus-metrics"
  template_id  = data.exoscale_compute_template.computeTemp.id
  size         = "Micro"
  disk_size    = 10
  state        = "Running"
  security_group_ids = [exoscale_security_group.secgroup1.id]
  user_data = <<EOF
#!/bin/bash
set -e

# region Install Docker
apt-get update
apt-get install -y curl
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh


sudo touch /tmp/config.json

sudo echo "
global:
  scrape_interval: 10s
scrape_configs:
  - job_name: Monitor all instance pools
    file_sd_configs:
      - files:
          - /srv/service-discovery/config.json
        refresh_interval: 5s
" >/prometheus.yml

sudo docker run -d -p 9090:9090 \
  -v /tmp/config.json:/srv/service-discovery/config.json \
  -v /prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

sudo docker run -d -v /tmp/config.json:/srv/service-discovery/config.json  \
  --env EXOSCALE_KEY=${var.exoscale_key} \
  --env EXOSCALE_SECRET=${var.exoscale_secret} \
  --env EXOSCALE_INSTANCEPOOL_ID=${exoscale_instance_pool.compute_pool.id} \
  --env TARGET_PORT=9100 \
  --env EXOSCALE_ZONE=${local.zone} \
  seekaddo1/sds:latest

EOF
}