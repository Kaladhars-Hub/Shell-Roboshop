#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-058422fa498bf5032"

for instance in $@
do
    Instance_ID=$(aws ec2 run-instances --image-id ami-09c813fb71547fc4f --instance-type t3.micro --security-group-ids sg-058422fa498bf5032 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" --query 'Instances[0].InstanceId' --output text)

# Get Private IP
    if [ $instance != "frontend" ]; then
         IP=$(aws ec2 describe-instances --instance-ids i-067232f992b634acc --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    else
        IP=$(aws ec2 describe-instances --instance-ids i-067232f992b634acc --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    fi

    echo "$instance: $IP"    
done    

