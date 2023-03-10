#Network
#Compute Resource
#DB Server

resource "yandex_compute_instance" "db-" {
  name = "db-${count.index}"
  count = 1

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd8emvfmfoaordspe1jr"
      size = 20 
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
  
  scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys =  "${var.ssh_user}:${file(var.ssh_pub_key_file)}"
  }
}


