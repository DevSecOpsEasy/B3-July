# Define the assume role policy document for the EKS cluster
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    # Allow the EKS service to assume the role
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    # Allow action sts:AssumeRole
    actions = ["sts:AssumeRole"]
  }
}

# Create an IAM role for the EKS cluster
resource "aws_iam_role" "example" {
  name               = "eks-cluster-cloud"
  
  # Attach the assume role policy defined above
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach AmazonEKSClusterPolicy to the EKS cluster IAM role
resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the public subnets of the default VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create an EKS cluster and associate it with the IAM role and VPC configuration
resource "aws_eks_cluster" "example" {
  name     = "EKS_CLOUD"
  role_arn = aws_iam_role.example.arn

  # Configure the VPC subnets for the cluster
  vpc_config {
    subnet_ids = data.aws_subnets.public.ids
  }

  # Ensure IAM role permissions are created before EKS Cluster provisioning
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
  ]
}

# Create an IAM role for the EKS node group
resource "aws_iam_role" "example1" {
  name = "eks-node-group-cloud"

  # Define the assume role policy for EC2 instances (worker nodes)
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Attach AmazonEKSWorkerNodePolicy to the worker node IAM role
resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.example1.name
}

# Attach AmazonEKS_CNI_Policy to the worker node IAM role for network management
resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example1.name
}

# Attach AmazonEC2ContainerRegistryReadOnly policy to allow pulling images from ECR
resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.example1.name
}

# Create a node group for the EKS cluster with autoscaling enabled
resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "Node-cloud"
  node_role_arn   = aws_iam_role.example1.arn

  # Use the public subnets for the node group
  subnet_ids      = data.aws_subnets.public.ids

  # Configure scaling for the node group
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Use t2.medium instance type for the worker nodes
  instance_types = ["t2.medium"]

  # Ensure IAM role permissions are created before provisioning the node group
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}
