output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.jvb.dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.jvb.arn
}

output "nlb_zone_id" {
  description = "Zone ID of the Network Load Balancer"
  value       = aws_lb.jvb.zone_id
}

output "target_group_udp_arn" {
  description = "ARN of the UDP target group"
  value       = aws_lb_target_group.jvb_udp.arn
}

output "target_group_tcp_arn" {
  description = "ARN of the TCP target group"
  value       = aws_lb_target_group.jvb_tcp.arn
}
