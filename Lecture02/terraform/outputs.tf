output "db_internal_IP" {
  value = yandex_compute_instance.db-[*].network_interface.0.ip_address
}

output "db_external_IPs" {
  value = yandex_compute_instance.db-[*].network_interface.0.nat_ip_address
}


### The Ansible inventory file
resource "local_file" "AnsibleInventory" {
 content = templatefile("inventory.tmpl",
 {
  db-0-ip = yandex_compute_instance.db-[0].network_interface.0.nat_ip_address
 }
 )
 filename = "../ansible/inventory"
}

resource "local_file" "load-balance-hosts-file" {
 content = templatefile("hosts.tmpl",
  {
   db-0-ip = yandex_compute_instance.db-[0].network_interface.0.ip_address
  }
 )
 filename = "../ansible/roles/lb/files/hosts"
}

resource "local_file" "web-server-hosts-file" {
 content = templatefile("hosts.tmpl",
  {
   db-0-ip = yandex_compute_instance.db-[0].network_interface.0.ip_address
  }
 )
 filename = "../ansible/hosts"
}

