# Домашнее задание к занятию «Отказоустойчивость в облаке» - Мельник Юрий Александрович


## Задание 1
### Возьмите за основу  
[решение к заданию 1 из занятия «Подъём инфраструктуры в Яндекс Облаке»](https://github.com/netology-code/sdvps-homeworks/blob/main/7-03.md#задание-1)

1. `Теперь вместо одной виртуальной машины сделайте terraform playbook, который:`   
 * создаст 2 идентичные виртуальные машины. Используйте аргумент [count](https://www.terraform.io/docs/language/meta-arguments/count.html) для создания таких ресурсов;  
 * создаст [таргет-группу](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/lb_target_group). Поместите в неё созданные на шаге 1 виртуальные машины;  
 * создаст [сетевой балансировщик нагрузки](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/lb_network_load_balancer), который слушает на порту 80, отправляет трафик на порт 80 виртуальных машин и http healthcheck на порт 80 виртуальных машин.  
   
   
 Рекомендуем изучить [документацию сетевого балансировщика нагрузки](https://cloud.yandex.ru/docs/network-load-balancer/quickstart) для того, чтобы было понятно, что вы сделали.  
 
2. `Установите на созданные виртуальные машины пакет Nginx любым удобным способом и запустите Nginx веб-сервер на порту 80.`  
3. `Перейдите в веб-консоль Yandex Cloud и убедитесь, что:`
 * созданный балансировщик находится в статусе Active,
 * обе виртуальные машины в целевой группе находятся в состоянии health
4. `Сделайте запрос на 80 порт на внешний IP-адрес балансировщика и убедитесь, что вы получаете ответ в виде дефолтной страницы Nginx.`

### В качестве результата пришлите:
1. `Terraform Playbook.`
2. `Скриншот статуса балансировщика и целевой группы.`
3. `Скриншот страницы, которая открылась при запросе IP-адреса балансировщика.`

 
## Решение 1
1. `Для решения задачи используем следующий 1. Terraform Playbook.`  
Листинг  example.tf  
```
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

```


Листинг  meta.txt 
```  
#cloud-config
datasource:
 Ec2:
  strict_id: false
ssh_pwauth: no
users:
- name: testuser
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJ/8nl4RWFm+0oXUDpUSjuOP3AHCl2E/af1CpzwhtO6 lamer@lamer-VirtualBox
#cloud-config
runcmd: []
```

2. `Выполним Terraform plan `  
Для проверки корректности работы скрипта  
```
terraform init
```

 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1.jpg)  
	

```
terraform plan
```
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_1.jpg)  
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_2.jpg)  


```
terraform apply
```
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_3.jpg)  
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_4.jpg)  
 
 
Проверим наличие виртуальных машин в консоли  яндекс облака
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_5.jpg)  
 
Проверим наличие балансировщика в консоли  яндекс облака
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_6.jpg)  
 
Получили IP Адреса  
Балансировщик - 158.160.164.79  
Машина  vm0         ip - 172.24.8.12  ip_nat -  158.160.24.247  
Машина  vm0         ip - 172.24.8.18  ip_nat -   51.250.97.155  


 
3. `установим  Nginx помощью ansible`  

Листинг install.yaml  
```
- name: web1
  hosts: my
  remote_user: testuser
  become: yes
  tasks:
  
    - name: Возврат информации об установленных пакетах как факты
      package_facts:
        manager: "auto"
    
    - name: Update apt cache and install Nginx if not install Nginx
      apt:
        name: nginx
        state: latest
        update_cache: yes
      when: "'nginx' not in ansible_facts.packages"
    
      
    - name: Get nginx Service Status
      ansible.builtin.systemd:
        name: "nginx"
      register: nginx_service_status

- name: web1
  hosts: my1
  remote_user: testuser
  become: yes
  tasks:

     - name: замена сервер1 
       replace:
         path: "/var/www/html/index.nginx-debian.html"
         regexp: '^<h1>Welcome to nginx!</h1>$'
         replace: '<h1>Welcome to nginx! server1</h1> '

- name: web2
  hosts: my2
  remote_user: testuser
  become: yes
  tasks:

     - name: замена сервер2 
       replace:
         path: "/var/www/html/index.nginx-debian.html"
         regexp: '^<h1>Welcome to nginx!</h1>$'
         replace: '<h1>Welcome to nginx! server2</h1> '
```
Установим Nginx
На первом сервере изменим заголовок 
Welcome to nginx!
На 
Welcome to nginx! server1

На втором сервере изменим заголовок 
Welcome to nginx!
На 
Welcome to nginx! Server2


Это позволит понять идет ли балансировка на оба сервера 

Изменим настройки anssible 


 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_7.jpg)  
 
ansible-playbook install.yaml
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_8.jpg)  
 
Балансировщик  увидел работающие сервера nginx
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_9.jpg)  
 
Проверим работу балансировщика 
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_10.jpg)  
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_11.jpg)  
 
Подключимся к первой машине и принудительно выключим nginx
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_12.jpg)  
 
Проверим статус балансировщика в консоле  яндекс облака
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_13.jpg)  
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_14.jpg)  
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_15.jpg)  

Балансировка идет только на сервер 2
 ![alt text](https://github.com/ysatii/fault_tolerance_cloud/blob/main/img/image1_16.jpg)  
