provider "aws" {
  region = var.region
}

# 1. Network (VPC) - Private Subnets for Security
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.1.1"

  name = "titan-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Save cost for dev/portfolio
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# 2. EKS Cluster (The Control Plane)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # 3. Node Group (The L40S GPU Workers)
  eks_managed_node_groups = {
    titan_gpu_nodes = {
      min_size     = 1
      max_size     = 5
      desired_size = 1

      instance_types = ["g6.xlarge"] # AWS L40S Instance
      ami_type       = "AL2_x86_64_GPU" # Amazon Linux 2 with NVIDIA Drivers

      # Storage for Model Weights (Need space for Ministral 14B)
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
    }
  }
}