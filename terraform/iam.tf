resource "aws_iam_role" "AWSServiceRoleForECS" {
  name               = "AWSServiceRoleForECS"
  assume_role_policy = file("policies/assume-role-policy.json")
}

resource "aws_iam_role_policy" "AmazonECS_FullAccess" {
  name   = "AmazonECS_FullAccess"
  policy = file("policies/AmazonECS_FullAccess.json")
  role   = aws_iam_role.ecsInstanceRole.id
}


resource "aws_iam_instance_profile" "ecs-instance-role-django" {
  name = "ecs-instance-role-django"
  path = "/"
  role = aws_iam_role.ecs-instance-role-django.name
}