terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  #required_version = ">= 0.13"
}

provider "yandex" {
  cloud_id  = "b1ggavufohr5p1bfj10e"
  folder_id = "b1g0hcgpsog92sjluneq"
  zone      = "ru-central1-b"
}

resource "yandex_compute_instance" "vm" {
  count = 2
  name = "vm${count.index}"
  platform_id = "standard-v1"
  boot_disk {
    initialize_params {
    image_id = "fd866kfu2hbk46j2e21q" # debian-12-v20240311
    size = 5
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
  metadata = {
    user-data = "${file("./meta.txt")}"
  }
  resources {
    core_fraction = 5
    cores  = 2
    memory = 2
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network-1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet-1"
  v4_cidr_blocks = ["172.24.8.0/24"]
  network_id     = yandex_vpc_network.network-1.id
}


resource "yandex_lb_target_group" "demo-1" {
  name = "demo-1"
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm[0].network_interface.0.ip_address
  }
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb-1" {
  name = "lb-1"
  deletion_protection = "false"
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.demo-1.id
    healthcheck { # проверка 80 порта
      name = "http"
        http_options {
          port = 80
          path = "/"
        }
    }
  }
}

output "vms_ip_info" {
  description = "General information about created VMs"
  value = [
    for virt in yandex_compute_instance.vm : {
      id = virt.name
      ip_nat = virt.network_interface[0].nat_ip_address
      ip = virt.network_interface[0].ip_address
    }
  ]
}


#output "lb_ip_address" {
#  value = yandex_lb_network_load_balancer.lb-1.listener.external_address_spec[0].address
# }

output "lb_ip_address_lb" {
  value = [for s in yandex_lb_network_load_balancer.lb-1.listener: s.external_address_spec]
}





