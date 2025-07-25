resource "sdm_node" "proxy_cluster" {
  proxy_cluster {
    name = var.sdm_cluster_name
    address = "${aws_lb.sdm_nlb.dns_name}:443"
  }  
}

resource "sdm_proxy_cluster_key" "proxy_key" {
  proxy_cluster_id = sdm_node.proxy_cluster.id
}

output "sdm_access_key" {
  value     = sdm_proxy_cluster_key.proxy_key.id
  sensitive = true
}
output "sdm_secret_key" {
  value     = sdm_proxy_cluster_key.proxy_key.secret_key
  sensitive = true
}
