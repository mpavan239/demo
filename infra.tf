# Create an ECS service for the application
resource "aws_ecs_service" "demo_service" {
  name            = "demo-service"
  cluster         = demo-cluster
  
  task_definition = "arn:aws:ecs:ap-south-1:634441478571:task-definition/demo-task-definition:6"
  
  desired_count   = 1

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    security_groups = [sg-0d1ee26c7d1db2194]
    subnets         = [subnet-01c2744b9cc6583b3]
    
  }

  load_balancer {
    target_group_arn = arn:aws:elasticloadbalancing:ap-south-1:634441478571:targetgroup/demo-target-group/3cc40d16860b5b21
    container_name   = "demo-app"
    container_port   = 3000
  }
}
