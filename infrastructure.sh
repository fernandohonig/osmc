#!/bin/bash

if [[ ! $# -eq 6 ]] ; then
        echo "Usage: infrastructure.sh <IPSUBNET-1> <REGION-1> <IPSUBNET-2> <REGION-2> <ACTION> <STACK>"
		exit
fi

export IPSUBNET1=$1
export AWSREGION1=$2
export IPSUBNET2=$3
export AWSREGION2=$4
export STACK=$6
export ACTION=$5
export PRE1=`echo $IPSUBNET1| awk -F "/" {'print $1'}| awk -F "." {'print $1"."$2"."$3'}`
export PRE2=`echo $IPSUBNET2| awk -F "/" {'print $1'}| awk -F "." {'print $1"."$2"."$3'}`

export PublicSubnetRange1="$PRE1.0/24"
export PublicSubnetRange2="$PRE2.0/24"


#Credentials setup:
CRED=/opt/conf/credentials
PK=/opt/conf/EC2_PRIVATE_KEY
CERT=/opt/conf/EC_CERT

case $ACTION:$STACK in

	create:vpc)
		
		
		DomainName1="ec2.internal"
		DomainName2="us-west-1.compute.internal"
		
		cfn-create-stack VPCBaseStack --region $AWSREGION1 --template-file /opt/scripts/base/VPC.template --parameters "PublicSubnetRange=$PublicSubnetRange1;VPCCidr=$IPSUBNET1;NATIntIP=$PRE1.253;DomainName=$DomainName1" --aws-credential-file $CRED

		cfn-create-stack VPCBaseStack --region $AWSREGION2 --template-file /opt/scripts/base/VPC.template --parameters "PublicSubnetRange=$PublicSubnetRange2;VPCCidr=$IPSUBNET2;NATIntIP=$PRE2.253;DomainName=$DomainName2" --aws-credential-file $CRED
		
	;;
	delete:vpc)
		cfn-delete-stack VPCBaseStack --region $AWSREGION1 --force --aws-credential-file $CRED
		cfn-delete-stack VPCBaseStack --region $AWSREGION2 --force --aws-credential-file $CRED
	;;
	create:monit)
		# Get Variables for Monitoring

		VPCId1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPC | awk '{print $3}'`
		VPCId2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPC | awk '{print $3}'`

		VPCSGId1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`
		VPCSGId2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`

		PublicSubnet1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w Subnet | awk '{print $3}'`
		PublicSubnet2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w Subnet | awk '{print $3}'`
		
		KeyName="key_demo"
		DefaultRoute1="$PRE1.1"
		VPNInstanceIP1="$PRE1.250"
		DefaultRoute2="$PRE2.1"
		VPNInstanceIP2="$PRE2.250"		
		MonitInstanceType="m1.large"
		InstanceHostType="preprod-servers,prod-servers,linux-servers,nagios-servers"
		MONAZs1=`ec2-describe-subnets --region $AWSREGION1 --private-key $PK --cert $CERT | grep SUBNET | grep $VPCId1 | grep $PublicSubnet1 | awk {'print $7'}`
		MONAZs2=`ec2-describe-subnets --region $AWSREGION2 --private-key $PK --cert $CERT | grep SUBNET | grep $VPCId2 | grep $PublicSubnet2 | awk {'print $7'}`
		
		# Create Monitoring System in 2 regions

		cfn-create-stack MonBaseStack --region $AWSREGION1 --template-file /opt/scripts/base/Monitoring.template --parameters "KeyName=$KeyName;VPCId=$VPCId1;VPNInstanceIP=$VPNInstanceIP1;DefaultRoute=$DefaultRoute1;VPCSGId=$VPCSGId1;MonitInstanceType=$MonitInstanceType;InstanceHostType=$InstanceHostType;PublicSubnet=$PublicSubnet1;MONAZs=$MONAZs1" --aws-credential-file $CRED

		cfn-create-stack MonBaseStack --region $AWSREGION2 --template-file /opt/scripts/base/Monitoring.template --parameters "KeyName=$KeyName;VPCId=$VPCId2;VPNInstanceIP=$VPNInstanceIP2;DefaultRoute=$DefaultRoute2;VPCSGId=$VPCSGId2;MonitInstanceType=$MonitInstanceType;InstanceHostType=$InstanceHostType;PublicSubnet=$PublicSubnet2;MONAZs=$MONAZs2" --aws-credential-file $CRED	
		
		sleep 30
		ELB1=`elb-describe-lbs --region $AWSREGION1 --aws-credential-file $CRED | grep MonBase | awk {'print $3'}`
		echo "DNS Monitoring East - " http://$ELB1/nagios
		ELB2=`elb-describe-lbs --region $AWSREGION2 --aws-credential-file $CRED | grep MonBase | awk {'print $3'}`
		echo "DNS Monitoring West - " http://$ELB2/nagios
	;;
	delete:monit)
		cfn-delete-stack MonBaseStack --region $AWSREGION1 --force --aws-credential-file $CRED
		cfn-delete-stack MonBaseStack --region $AWSREGION2 --force --aws-credential-file $CRED	
	;;
	create:dashboard)
		# Get Variables for Monitoring

		VPCId1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPC | awk '{print $3}'`
		VPCId2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPC | awk '{print $3}'`

		VPCSGId1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`
		VPCSGId2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`

		PublicSubnet1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w Subnet | awk '{print $3}'`
		PublicSubnet2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w Subnet | awk '{print $3}'`
		
		KeyName="key_demo"
		DefaultRoute1="$PRE1.1"
		VPNInstanceIP1="$PRE1.250"
		DefaultRoute2="$PRE2.1"
		VPNInstanceIP2="$PRE2.250"		
		MONAZs1=`ec2-describe-subnets --region $AWSREGION1 --private-key $PK --cert $CERT | grep SUBNET | grep $VPCId1 | grep $PublicSubnet1 | awk {'print $7'}`
		MONAZs2=`ec2-describe-subnets --region $AWSREGION2 --private-key $PK --cert $CERT | grep SUBNET | grep $VPCId2 | grep $PublicSubnet2 | awk {'print $7'}`
		
		# Get IP of each Monitoring System

		ELB1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name MonBaseStack --aws-credential-file $CRED | grep -w MonitoringELB | awk {'print $3'}`
		
		MONID1=`elb-describe-lbs $ELB1 --region $AWSREGION1 --aws-credential-file $CRED --show-long | awk -F "," {'print $14'}`

		MonitInstanceIP1=`ec2-describe-instances --region $AWSREGION1 --private-key $PK --cert $CERT | grep $MONID1 | grep 'INSTANCE' | awk {'print $13'}`		
				
		ELB2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name MonBaseStack --aws-credential-file $CRED | grep -w MonitoringELB | awk {'print $3'}`
		
		MONID2=`elb-describe-lbs $ELB2 --region $AWSREGION2 --aws-credential-file $CRED --show-long | awk -F "," {'print $14'}`

		MonitInstanceIP2=`ec2-describe-instances --region $AWSREGION2 --private-key $PK --cert $CERT | grep $MONID2 | grep 'INSTANCE' | awk {'print $13'}`				
		
		# Get Variables for Dashboard
		InstanceHostType="prod-servers,preprod-servers,linux-servers,nagvis-servers"
		DashboardInstanceType="m1.large"
		
		# Create Dashboard System in 2 regions

		cfn-create-stack DashboardStack --region $AWSREGION1 --template-file /opt/scripts/base/Dashboard.template --parameters "KeyName=$KeyName;VPCId=$VPCId1;VPNInstanceIP=$VPNInstanceIP1;DefaultRoute=$DefaultRoute1;VPCSGId=$VPCSGId1;DashboardInstanceType=$DashboardInstanceType;InstanceHostType=$InstanceHostType;PublicSubnet=$PublicSubnet1;MONAZs=$MONAZs1;MonitInstanceIP=$MonitInstanceIP1;MonitInstanceIP2=$MonitInstanceIP2;" --aws-credential-file $CRED
		
		cfn-create-stack DashboardStack --region $AWSREGION2 --template-file /opt/scripts/base/Dashboard.template --parameters "KeyName=$KeyName;VPCId=$VPCId2;VPNInstanceIP=$VPNInstanceIP2;DefaultRoute=$DefaultRoute2;VPCSGId=$VPCSGId2;DashboardInstanceType=$DashboardInstanceType;InstanceHostType=$InstanceHostType;PublicSubnet=$PublicSubnet2;MONAZs=$MONAZs2;MonitInstanceIP=$MonitInstanceIP2;MonitInstanceIP2=$MonitInstanceIP1;" --aws-credential-file $CRED
		sleep 30
		ELB1=`elb-describe-lbs --region $AWSREGION1 --aws-credential-file $CRED | grep Dashb | awk {'print $3'}`
		echo "DNS Nagvis East - " http://$ELB1/nagvis
		echo "DNS Thruk East - " http://$ELB1/thruk
		ELB2=`elb-describe-lbs --region $AWSREGION2 --aws-credential-file $CRED | grep Dashb | awk {'print $3'}`
		echo "DNS Nagvis West - " http://$ELB2/nagvis 
		echo "DNS Thruk West - " http://$ELB2/thruk
	;;
	delete:dashboard)
		cfn-delete-stack DashboardStack --region $AWSREGION1 --force --aws-credential-file $CRED
		cfn-delete-stack DashboardStack --region $AWSREGION2 --force --aws-credential-file $CRED	
	;;
	create:nat)
		# Get Variables for NAT


		PublicSubnet1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w Subnet | awk '{print $3}'`

		PublicSubnet2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w Subnet | awk '{print $3}'`

		VPCSGId1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`
		VPCSGId2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`

		#Get EIP for region1 and region2

		EIP1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w EIP | awk '{print $3}'`

		EIP2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w EIP | awk '{print $3}'`

		#Get EIP Alloc

		EIPALLOC1=`ec2-describe-addresses --region $AWSREGION1 --private-key $PK --cert $CERT | grep -w $EIP1 | awk '{print $4}'`

		EIPALLOC2=`ec2-describe-addresses --region $AWSREGION2 --private-key $PK --cert $CERT | grep -w $EIP2 | awk '{print $4}'`

		KeyName="key_demo"
		VPNVMName1="vpninstance01"
		VPNVMName2="vpninstance02"
		BastionVMName1="bstinstance01"
		VPC1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPC | awk {'print $3'}`
		VPC2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPC | awk {'print $3'}`
		ENIIP1="$PRE1.253"
		InstanceIP1="$PRE1.250"
		InstanceIP1B="$PRE1.251"
		ENIIP2="$PRE2.253"
		InstanceIP2="$PRE2.250"
		InstanceIP2B="$PRE2.251"
		VPNInstanceType="m1.small"
		RemoteVPCcidr1=$IPSUBNET2
		RemoteVPCcidr2=$IPSUBNET1
		RemoteCIDRmask="255.255.0.0"
		RemoteVPNIPCidr1="$EIP2"/32
		RemoteVPNIPCidr2="$EIP1"/32
		RemoteVPNIP1=$EIP2
		RemoteVPNIP2=$EIP1
		VPNKey="duvuwrApeXe9e42tHEthestEThUFebr4thEprubr8dresPestuvacHes7uStaPHu"
		InstanceHostType="linux-servers,nat-servers"
		echo "VPN Endpoint East - " $EIP1
		echo "VPN Endpoint West - " $EIP2
		
		# Get ENI ID

		ENINAME1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w NetworkInterface | awk '{print $3}'`

		ENINAME2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w NetworkInterface | awk '{print $3}'`		
		
		# Create NAT Instances and Security Group

		cfn-create-stack NATBaseStack --region $AWSREGION1 --template-file /opt/scripts/base/NAT_VPN.template --parameters "KeyName=$KeyName;VPC=$VPC1;VPNEni=$ENINAME1;VPCSecurityGroup=$VPCSGId1;PublicSubnet=$PublicSubnet1;VPNInstanceIP=$ENIIP1;VPNVMName1=$VPNVMName1;VPNVMName2=$VPNVMName2;BastionVMName1=$BastionVMName1;VPNInstanceType=$VPNInstanceType;VPNInstanceIP1=$InstanceIP1;VPNInstanceIP2=$InstanceIP1B;RemoteVPCcidr=$RemoteVPCcidr1;RemoteCIDRmask=$RemoteCIDRmask;RemoteVPNIPCidr=$RemoteVPNIPCidr1;VPNEIPAlloc=$EIPALLOC1;RemoteVPNIP=$RemoteVPNIP1;VPNKey=$VPNKey;VPCCidr=$IPSUBNET1;VPNInstanceEIP=$EIP1;InstanceHostType=$InstanceHostType;" --aws-credential-file $CRED

		cfn-create-stack NATBaseStack --region $AWSREGION2 --template-file /opt/scripts/base/NAT_VPN.template --parameters "KeyName=$KeyName;VPC=$VPC2;VPNEni=$ENINAME2;VPCSecurityGroup=$VPCSGId2;PublicSubnet=$PublicSubnet2;VPNInstanceIP=$ENIIP2;VPNVMName1=$VPNVMName1;VPNVMName2=$VPNVMName2;BastionVMName1=$BastionVMName1;VPNInstanceType=$VPNInstanceType;VPNInstanceIP1=$InstanceIP2;VPNInstanceIP2=$InstanceIP2B;RemoteVPCcidr=$RemoteVPCcidr2;RemoteCIDRmask=$RemoteCIDRmask;RemoteVPNIPCidr=$RemoteVPNIPCidr2;VPNEIPAlloc=$EIPALLOC2;RemoteVPNIP=$RemoteVPNIP2;VPNKey=$VPNKey;VPCCidr=$IPSUBNET2;VPNInstanceEIP=$EIP2;InstanceHostType=$InstanceHostType;" --aws-credential-file $CRED
		
		# Assign VPCSGid to ENI

		VPCSGId1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`

		ec2mnicatt --region $AWSREGION1 $ENINAME1 --group-id $VPCSGId1 --private-key $PK --cert $CERT

		VPCSGId2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w VPCSecurityGroup | awk '{print $3}'`

		ec2mnicatt --region $AWSREGION2 $ENINAME2 --group-id $VPCSGId2 --private-key $PK --cert $CERT

	;;
	delete:nat)	
		#Get EIP for region1 and region2

		EIP1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w EIP | awk '{print $3}'`

		EIP2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w EIP | awk '{print $3}'`
		
		ENINAME1=`cfn-list-stack-resources --region $AWSREGION1 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w NetworkInterface | awk '{print $3}'`

		ENINAME2=`cfn-list-stack-resources --region $AWSREGION2 --stack-name VPCBaseStack --aws-credential-file $CRED | grep -w NetworkInterface | awk '{print $3}'`
		
		ENIATT1=`ec2dnic --region $AWSREGION1 $ENINAME1 --private-key $PK --cert $CERT | grep ATTACHMENT | awk {'print $3'}`
		ENIATT2=`ec2dnic --region $AWSREGION2 $ENINAME2 --private-key $PK --cert $CERT | grep ATTACHMENT | awk {'print $3'}`
		
		EIPALLOC1=`ec2-describe-addresses --region $AWSREGION1 --private-key $PK --cert $CERT | grep -w $EIP1 | awk '{print $6}'`

		EIPALLOC2=`ec2-describe-addresses --region $AWSREGION2 --private-key $PK --cert $CERT | grep -w $EIP2 | awk '{print $6}'`
		
		ec2disaddr --region $AWSREGION1 -a $EIPALLOC1 --private-key $PK --cert $CERT 
		ec2disaddr --region $AWSREGION2 -a $EIPALLOC2 --private-key $PK --cert $CERT 
		sleep 30
		ec2-detach-network-interface --region $AWSREGION1 $ENIATT1 -f --private-key $PK --cert $CERT 
		ec2-detach-network-interface --region $AWSREGION2 $ENIATT2 -f --private-key $PK --cert $CERT	
		sleep 30
		cfn-delete-stack NATBaseStack --region $AWSREGION1 --force --aws-credential-file $CRED
		cfn-delete-stack NATBaseStack --region $AWSREGION2 --force --aws-credential-file $CRED		
	;;
esac