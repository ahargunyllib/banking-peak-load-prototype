#!/usr/bin/bash
export TF_VAR_db_password="Admin123!!ABC"
export TF_VAR_mq_password="Admin123!!ABC"

terraform import module.alb.aws_security_group.alb sg-0646312da7ab2b18a
terraform import module.elasticache.aws_security_group.redis sg-0b59976cc2dff5135
terraform import module.rds.aws_security_group.rds sg-08af067ec89c4a3ab
terraform import module.rabbitmq.aws_security_group.mq sg-04ac64b842fe9b5d0
