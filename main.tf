# main.tf - Root module

module "vpc" {
  source = "./modules/vpc"
  
  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "fargate_profiles" {
  source = "./modules/fargate-profiles"
  
  cluster_name       = module.eks.cluster_name
  test_app_namespace = var.test_app_namespace
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Wait for the EKS cluster to be ready before creating Fargate profiles
  depends_on = [module.eks]
}

module "logging" {
  source = "./modules/logging"
  
  cluster_name = module.eks.cluster_name
  
  depends_on = [module.eks]
}

module "monitoring" {
  source = "./modules/monitoring"
  
  cluster_name = module.eks.cluster_name
  
  depends_on = [module.eks]
}