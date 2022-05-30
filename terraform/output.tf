output "db-endpoint" {
    value = aws_db_instance.default.endpoint
}

output "db-address" {
    value = aws_db_instance.default.address
}

output "elb_dns_name" {
  value       = aws_elb.sample.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.asg-sample.name
  description = "The name of the Auto Scaling Group"
}