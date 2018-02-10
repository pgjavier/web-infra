# Public Load Balancer

output "frontend_address" {
  value = "${aws_elb.elb_frontend.dns_name}"
}
