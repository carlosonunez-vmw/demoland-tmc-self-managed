output "jumpbox_ip" {
  value = module.jumpbox.public_ip
}

output "jumpbox_private_key" {
  value     = module.key_pair.private_key_openssh
  sensitive = true
}

output "user" {
  value     = "ubuntu"
  sensitive = true
}

output "registry_url" {
  value = module.repository.repository_url
}
