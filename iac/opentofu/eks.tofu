module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  name       = "${var.project_name}-${var.environment}"

  kubernetes_version = var.kubernetes_version
  deletion_protection = var.environment == "dev" ? false : true

  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  encryption_config = {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
  }

  # Add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      ami_type       = "BOTTLEROCKET_x86_64"
      disk_size      = var.node_disk_size

      vpc_security_group_ids = [aws_security_group.node_group_additional.id]

      update_config = {
        max_unavailable_percentage = 25
      }

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      tags = {
        ExtraTag = "EKS managed node group"
      }
    }
  }

  addons = {
    coredns                = {}
    kube-proxy             = {}
    aws-ebs-csi-driver     = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-secrets"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_security_group" "node_group_additional" {
  name_prefix = "${var.project_name}-${var.environment}-node-additional"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow ALB to communicate with node groups"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-node-additional"
  }
}
