provider "aws" {
  region = var.region
}

# 1. Network (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0" # Pinned to stable v5

  name = "titan-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Required tags for EKS Load Balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  }
}

# 2. EKS Cluster (Control Plane)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" # UPGRADED: Fixed Elastic GPU error

  cluster_name    = var.cluster_name
  cluster_version = "1.29" # Modern K8s version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Security: Allow you to access the cluster API
  cluster_endpoint_public_access = true

  # ACCESS CONTROL (The v20 Change):
  # Grants the creator (your IAM user) admin access automatically
  enable_cluster_creator_admin_permissions = true

  # 3. Node Group (The L40S GPU Workers)
  eks_managed_node_groups = {
    titan_gpu_nodes = {
      min_size     = 1
      max_size     = 5
      desired_size = 1

      # L40S Instance Configuration
      instance_types = ["g6e.xlarge"]
      
      # Use the correct AMI for GPU support
      ami_type       = "AL2_x86_64_GPU" 

      # Storage for Model Weights
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        "accelerator" = "nvidia-l40s"
      }
      
      # Taints prevent non-GPU pods from scheduling here (Optional but Recommended)
      # taints = {
      #   dedicated = {
      #     key    = "nvidia.com/gpu"
      #     value  = "true"
      #     effect = "NO_SCHEDULE"
      #   }
      # }
    }
  }

  tags = {
    Environment = "production"
    Project     = "titan-inference"
  }
}