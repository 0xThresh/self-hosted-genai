module "postgres-db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "genai-postgres"

  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14"
  major_engine_version = "14"
  instance_class       = "db.t3.medium"

  allocated_storage     = 200
  max_allocated_storage = 500

  db_name  = "genaidb"
  username = "genaiuser"
  port     = 5432

  manage_master_user_password = true

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.public.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"
}

resource "aws_db_subnet_group" "public" {
  name       = "genai-private"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "GenAI Public Subnet Group"
  }
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "rds" {
  name_prefix = "genai-rds"
  vpc_id      = module.vpc.vpc_id

  # ingress {
  #   from_port       = 5432
  #   to_port         = 5432
  #   protocol        = "tcp"
  #   security_groups = [module.genai-eks.cluster_security_group_id]
  # }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    description = "Allow access from my current IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GenAI RDS Security Group"
  }
}

resource "null_resource" "enable_pgvector" {
  depends_on = [module.postgres-db]

  provisioner "local-exec" {
    command = <<-EOT
      SECRET=$(aws secretsmanager get-secret-value --secret-id ${module.postgres-db.db_instance_master_user_secret_arn} --query SecretString --output text)
      PASSWORD=$(echo $SECRET | jq -r .password)
      echo "Connecting to database ${module.postgres-db.db_instance_address}..." >> pgvector_setup.log
      PGPASSWORD=$PASSWORD psql -h ${module.postgres-db.db_instance_address} -U ${module.postgres-db.db_instance_username} -d ${module.postgres-db.db_instance_name} -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 | tee -a pgvector_setup.log
      echo "Command completed at $(date)" >> pgvector_setup.log
    EOT
  }
