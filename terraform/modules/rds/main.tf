resource "aws_db_instance" "postgres" {
  identifier             = "atlasrelay-postgres"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "platformadmin"
  password               = "ChangeMe123!"
  skip_final_snapshot    = true
  publicly_accessible    = false
}
