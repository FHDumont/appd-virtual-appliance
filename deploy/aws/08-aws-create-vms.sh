#!/usr/bin/env bash
# shellcheck disable=SC2181,SC2086,SC1091

### Config ###
# shellcheck source-path=SCRIPTDIR
source config.cfg 
#############

AMI_ID=$(awk -F ': ' '/ami_id/ {print $2}' ami.id)
if [ -z "${AMI_ID}" ]; then
    echo "Missing required AMI_ID value"
    exit 1
fi

# get subnet id
subnetID=$(aws --profile ${AWS_PROFILE} ec2 describe-subnets --output text --filters Name=tag-value,Values="${SUBNET_NAME}" --query 'Subnets[*].SubnetId')
# aws --profile va-deployment ec2 describe-subnets --output text --filters Name=tag-value,Values=appd-va-subnet-1 --query 'Subnets[*].SubnetId'
# subnet-064d56222e2fb2ce3
if [ -z "${subnetID}" ]; then
    echo "Did not find a subnet with name $SUBNET_NAME, exiting"
    exit 1
fi

# get security group id
sgID=$(aws --profile ${AWS_PROFILE} ec2 describe-security-groups --output text --filters Name=tag-value,Values="${SG_NAME}" --query 'SecurityGroups[*].GroupId')
# sgID=$(aws --profile va-deployment ec2 describe-security-groups --output text --filters Name=tag-value,Values="appd-va-sg-1" --query 'SecurityGroups[*].GroupId')
# sg-026333e5679d8f5ca
if [ -z "$sgID" ]; then
    echo "Did not find a security group with the name $SG_NAME, exiting"
    exit 1
fi

echo "Creating the VMs ..."
for VM_ID in 1 2 3; do
    VM_NAME_VAR="VM_NAME_${VM_ID}"
    VM_NAME="${!VM_NAME_VAR}"

    cat > user-data.ec2 <<EOF
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    netplan:
      dhcp4: true
      dhcp6: false
EOF

    # Create network interface
    network_intf_id=$(aws --profile ${AWS_PROFILE} ec2 create-network-interface \
                          --subnet-id "$subnetID" \
                          --description "VA Network Interface" \
                          --groups "$sgID" \
                          --query 'NetworkInterface.NetworkInterfaceId' --output text)
    # aws --profile va-deployment ec2 create-network-interface --subnet-id "subnet-064d56222e2fb2ce3" --description "VA Network Interface"  --groups "sg-026333e5679d8f5ca"  --query 'NetworkInterface.NetworkInterfaceId' --output text
    # eni-04bf5a29b2573c29a

    # Allocate an Elastic IP
    allocation_id=$(aws --profile ${AWS_PROFILE} ec2 allocate-address \
                        --domain vpc \
                        --query 'AllocationId' --output text)
    # aws --profile va-deployment ec2 allocate-address  --domain vpc  --query 'AllocationId' --output text
    # eipalloc-009984565c49aeca3

    # Associate the Elastic IP with the ENI
    aws ec2 --profile ${AWS_PROFILE} associate-address \
            --allocation-id ${allocation_id} \
            --network-interface-id ${network_intf_id}
    # aws ec2 --profile va-deployment associate-address  --allocation-id eipalloc-009984565c49aeca3 --network-interface-id eni-04bf5a29b2573c29a
    # eipassoc-0f39f5c76358133f5

    # requires Nitro instance types
    aws --profile ${AWS_PROFILE} ec2 run-instances \
        --image-id "$AMI_ID" \
	    --instance-type "${VM_TYPE}" \
        --network-interfaces "[{\"NetworkInterfaceId\":\"${network_intf_id}\",\"DeviceIndex\":0}]" \
        --block-device-mappings \
        "DeviceName=/dev/sda1,Ebs={VolumeSize=${VM_OS_DISK},VolumeType=gp3}" \
        "DeviceName=/dev/sdb,Ebs={VolumeSize=${VM_DATA_DISK},VolumeType=gp3,DeleteOnTermination=false}" \
	    --user-data file://user-data.ec2 \
        --no-cli-pager \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${VM_NAME}},${TAGS}]" 

done
