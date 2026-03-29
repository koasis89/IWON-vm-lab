
terraform output bastion_public_ip
"20.214.224.224"

terraform output vm_private_ips
{
  "app01" = "10.0.2.30"
  "bastion01" = "10.0.3.10"
  "db01" = "10.0.2.50"
  "kafka01" = "10.0.2.60"
  "smartcontract01" = "10.0.2.40"
  "was01" = "10.0.2.20"
  "web01" = "10.0.2.10"
}
