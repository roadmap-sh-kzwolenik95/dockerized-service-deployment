output "instance_ip_addr" {
  value = digitalocean_droplet.web.ipv4_address
}
