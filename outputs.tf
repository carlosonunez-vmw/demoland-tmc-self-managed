output "jumpbox_ip" {
  value = module.jumpbox.public_ip
}

output "jumpbox_private_key" {
  value     = module.key_pair.private_key_openssh
  sensitive = true
}
