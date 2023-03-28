
# Create an ECS service for the application
resource "aws_ecs_service" "demo_service" {
  name            = "demo-service"
  cluster         = aws_ecs_cluster.demo_cluster.id
  task_definition = aws_ecs_task_definition.demo_task_definition.arn
  desired_count   = 1

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    security_groups = [aws_security_group.demo_sg.id]
    subnets         = [aws_subnet.demo_sub_pvt.id]
    
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.demo_target_group.arn
    container_name   = "demo-app"
    container_port   = 3000
  }
}
