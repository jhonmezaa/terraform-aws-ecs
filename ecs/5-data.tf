# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Partition (aws, aws-cn, aws-us-gov)
data "aws_partition" "current" {}
