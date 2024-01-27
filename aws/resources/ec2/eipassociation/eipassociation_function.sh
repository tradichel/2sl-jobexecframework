#!/bin/bash -e
# https://github.com/tradichel/2sl-jobexecframework
# resources/ec2/vpc/vpc_functions.sh
# author: @teriradichel @2ndsightlab
# description: deploy a VPC
##############################################################

source shared/functions.sh
source shared/validate.sh
source resources/ec2/routetable/routetable_functions.sh

#for testing
get_github_ips(){

		api_line=$(curl -s https://api.github.com/meta --ipv4 | grep -n 'api' | cut -d ":" -f1 | head -1)
		pkg_line=$(curl -s https://api.github.com/meta --ipv4 | grep -n 'packages' | cut -d ":" -f1 | head -1)
		lines=$(( $pkg_line - $api_line ))

		echo $api_line
		echo $pkg_line
		echo $lines
		if [ "$lines" == "0" ]; then "echo invalid number of lines"; exit; fi

    ips=$(curl -s https://api.github.com/meta --ipv4 |
       grep 'api' -A $lines | sort | uniq |
       grep "/" | grep "\." | sed 's/"//g' | sed 's/ //g' | sed 's/,//g')

		c=0
		for ip in $ips
  	do
			c=$(($c + 1))
		done
		echo "$c ip addresses"
		echo $ips

}

deploy_github_prefix_list() {

  listname="GithubPrefixList"
	entries=""
	template="cfn/PrefixList-Github.yaml"
	
	if [ -f "$template" ]; then rm $template; fi

  api_line=$(curl -s https://api.github.com/meta --ipv4 | grep -n 'api' | cut -d ":" -f1 | head -1)
  pkg_line=$(curl -s https://api.github.com/meta --ipv4 | grep -n 'packages' | cut -d ":" -f1 | head -1)
  lines=$(( $pkg_line - $api_line ))
  if [ "$lines" == "0" ]; then "echo invalid number of lines. GitHub API Failed"; exit; fi

  ips=$(curl -s https://api.github.com/meta --ipv4 |
     grep 'api' -A $lines | sort | uniq |
     grep "/" | grep "\." | sed 's/"//g' | sed 's/ //g' | sed 's/,//g')

	for ip in $ips
	do
  	entries=$entries'        - Cidr: '$ip$'\\\n'
		entries=$entries$'          Description: github-git\\\n'
	done

	cat cfn/PrefixList.tmp | \
  sed 's*\[\[name\]\]*'$listname'*g'  | \
	sed 's*\[\[ips\]\]*'"$entries"'*' >> $template

	p=""
	resourcetype='PrefixList'
  deploy_stack $profile $listname $resourcetype $template "$p"

}


clean_up_default_sg(){

  vpcname="$1"

	echo "Clean up default security group"

  vpcid=$(get_vpc_id_by_name $vpcname)

  sgid=$(aws ec2 describe-security-groups \
        --filter Name=group-name,Values=default Name=vpc-id,Values=$vpcid \
        --query SecurityGroups[*].GroupId --output text --profile $profile)

  sgname=$vpcname'Default'

  aws ec2 create-tags \
    --resources $sgid \
    --tags 'Key="Name",Value="'$sgname'"' \
		--profile $profile

  name=$sgname'SecurityGroupRules'
  template='cfn/SGRules/NoAccess.yaml'
	exportparam=$vpcname'DefaultSecurityGroup'
  p=$(add_parameter "SGExportParam" $exportparam)
  resourcetype='SGRules'
  deploy_stack $profile $name $resourcetype $template "$p"

}

deploy_remote_access_sgs_for_group() {

	group="$1"
	vpc="$2"

	echo " --------------Deploy remote access security groups for $group --------------"
  function=${FUNCNAME[0]}
  validate_param "group" "$group" "$function"
  validate_param "vpc" "$vpc" "$function"

	members=$(get_users_in_group $group $profile)

	echo 'Members: '$members
	for user in ${members//,/ }
	do
		echo 'user: '$user
	
		#extract the username from the ARN
		user=$(echo $user | sed 's:.*/::')

    echo 'user: '$user

		echo "Enter the remote access cidr for user $user (IP with /32 at the end for a single IP address):"
		read allowcidr

		prefix="SSH$user"
		desc="SSHRemoteAccess-CantPassSpacesToCLIFixLater"
		template="cfn/SGRules/SSH.yaml"
		deploy_security_group $vpc $prefix $desc $template $allowcidr

		prefix="RDP$user"
		desc="RDPRemoteAccess-CantPassSpacesToCLIFixLater"
		template="cfn/SGRules/RDP.yaml"
		deploy_security_group $vpc $prefix $desc $template $allowcidr

  done

}

deploy_security_group() {

	vpc="$1"
	prefix="$2"
	desc="$3"
	rulestemplate="$4"
	cidr="$5"	

  function=${FUNCNAME[0]}
  validate_param "vpc" "$vpc" "$function"
  validate_param "prefix" "$prefix" "$function"
  validate_param "desc" "$desc" "$function"
  validate_param "rulestemplate" "$rulestemplate" "$function"

	template="cfn/SecurityGroup.yaml"
	resourcetype="SecurityGroup"	
	sgname=$vpc$prefix
	p=$(add_parameter "cfparamName" $sgname)
	p=$(add_parameter "VPCExportParam" $vpc $p)
	p=$(add_parameter "cfparamGroupDescription" "$desc" $p)
	
	deploy_stack $profile $sgname $resourcetype $template "$p"

	#pass in "none" for template if want to deploy template separately
	if [ "$rulestemplate" != "none" ]; then
	  deploy_sg_rules $sgname $rulestemplate $cidr
  fi

}

get_sgrules_parameters() {

		sgname="$1"
		cidr="$2"

    p=$(add_parameter "SGExportParam" $sgname)
    if [ "$cidr" != "" ]; then p=$(add_parameter "cfparamAllowCidr" "$cidr" $p); fi
		echo "$p"
}

deploy_sg_rules() {

	sgname="$1"
  template="$2"
	cidr="$3"

  function=${FUNCNAME[0]}
  validate_param "sgname" "$sgname" "$function"
  validate_param "template" "$template" "$function"
	#cidr is optional
	
  resourcetype='SGRules'
  p=$(get_sgrules_parameters $sgname $cidr)
  rulesname=$sgname'Rules'
  deploy_stack $profile $rulesname $resourcetype $template "$p"

}

deploy_vpce_sg_rules() {

  sgname="$1"
	service="$2"
	vpcname="$3"
	template="$4"

  function=${FUNCNAME[0]}
  validate_param "sgname" "$sgname" "$function"
  validate_param "vpcname" "$vpcname" "$function"
  validate_param "service" "$service" "$function"
  validate_param "template" "$template" "$function"

  p=$(add_parameter "SGExportParam" $sgname)
  p=$(add_parameter "cfparamService" $service $p)
  p=$(add_parameter "cfparamVPCName" $vpcname $p)

  resourcetype='SGRules'
  rulesname=$sgname'Rules'
  deploy_stack $profile $rulesname $resourcetype $template "$p"

}

#nacl name is subnet name less any index - NACL
deploy_nacl(){
	naclname="$1"
	vpcexport="$2"		
	naclrulestemplate="$3"

  template="cfn/NACL.yaml"
  resourcetype='NACL'
  p=$(add_parameter "cfparamName" $naclname)
  p=$(add_parameter "VPCExportParam" $vpcexport $p)
  deploy_stack $profile $naclname $resourcetype "$template" "$p"

  #add nacl rules
  resourcetype="NetworkACLEntry"
  name=$naclname'Entries'
  p=$(add_parameter "NACLExportParam" $naclname)
  deploy_stack $profile $name $resourcetype $naclrulestemplate "$p"

}

get_availability_zone () {
	index="$1"

	azid=$(aws ec2 describe-availability-zones --profile $profile \
			| grep "az$index" -B1 | grep -v "az$index" \
			| cut -d ":" -f2 | sed 's/ //g' | sed 's/"//g' | sed 's/,//g')

	echo $azid

}

deploy_subnet(){

	subnetname="$1"
  vpcprefix="$2"
	rttype="$3"
	cidrindex=$4 #one less than subnet index
	zoneindex=$5
	cidrbits=$6
	subnetcount=$7
  naclname="$8"
  routetablename="$9"
	
	vpc=$vpcprefix'VPC'
	vpccidr=$vpcprefix'VPCCIDR'

  function=${FUNCNAME[0]}
  validate_param "subnetname" "$subnetname" "$function"
  validate_param "vpc" "$vpc" "$function"
	validate_param "rttype" "$rttype" "$function"
  validate_param "cidrindex" "$cidrindex" "$function"
  validate_param "zoneindex" "$zoneindex" "$function"
  validate_param "cidrbits" "$cidrbits" "$function"
  validate_param "subnetcount" "$subnetcount" "$function"
	validate_param "naclname" "$naclname" "$function"
 	validate_param "routetablename" "$routetablename" "$function"

  az=$(get_availability_zone $zoneindex)

  resourcetype='Subnet'
  template='cfn/Subnet.yaml'  
	p=$(add_parameter "cfparamName" $subnetname)
  p=$(add_parameter "VPCExportParam" $vpc $p)
  p=$(add_parameter "AZParam" $az $p)
  p=$(add_parameter "VPCCidrExportParam" $vpccidr $p)
  p=$(add_parameter "CidrIndexParam" $cidrindex $p)
  p=$(add_parameter "CidrBitsParam" $cidrbits $p)  
  p=$(add_parameter "SubnetCountParam" $subnetcount $p)

	deploy_stack $profile $subnetname $resourcetype $template "$p"

	template=cfn/SubnetNACLAssociation.yaml
	resourcetype='SubnetNACLAssociation'

  timestamp="$(date)"
  t=$(echo $timestamp | sed 's/ //g')
  p=$(add_parameter "cfparamSubnetIdExport" $subnetname)
  p=$(add_parameter "NACLIdExportParam" $naclname $p) 
	p=$(add_parameter "cfparamTimestamp" $t $p)
	deploy_stack $profile $subnetname$naclname $resourcetype $template "$p"

  template=cfn/SubnetRouteTableAssociation.yaml
  resourcetype='SubnetRouteTableAssociation'
  timestamp="$(date)"
  t=$(echo $timestamp | sed 's/ //g')
  p=$(add_parameter "cfparamSubnetIdExport" $subnetname)
  p=$(add_parameter "cfparamRouteTableIdExport" $routetablename $p)
  p=$(add_parameter "cfparamTimestamp" $t $p)
  deploy_stack $profile $subnetname$routetablename $resourcetype $template "$p"

}

deploy_subnets(){
  vpc="$1"
  vpccidr="$2"
  subnetindex=$3
  firstzoneindex=$4
  cidrbits=$5
  naclrulestemplate=$6
	routetablename=$7

	sname="Subnet"

  i=0

  while (( $i < $subnetcount ));
  do

   #why not to use bash on the next line
   i=$((($i+1)))
   subnetname=$vpc$sname$i

	 deploy_subnet $vpc $subnetname $vpccidr $i $fistzoneindex $cidrbits $naclrulestemplate $routetablename

	done

}

#get the s3 prefix list for the current region
get_s3_prefix_list(){
	echo $(aws ec2 describe-managed-prefix-lists --filters Name=owner-id,Values=AWS --output text --profile $profile | grep s3 | cut -f5)
}

deploy_s3_security_group() {

  vpc="$1"
  prefix="$2"
  desc="$3"

  prefixlistid=$(get_s3_prefix_list)

  template="cfn/SecurityGroup.yaml"
  resourcetype="SecurityGroup"  
  sgname=$vpc$prefix
  p=$(add_parameter "cfparamName" $sgname)
  p=$(add_parameter "VPCExportParam" $vpc $p)
  p=$(add_parameter "cfparamGroupDescription" "$desc" $p)
  
  deploy_stack $profile $sgname $resourcetype $template "$p"

  name=$prefix'Rules'
  template='cfn/SGRules/S3.yaml'
  p=$(add_parameter "cfparamName" $name)
  p=$(add_parameter "SGExportParam" $sgname $p)
  p=$(add_parameter "cfparamS3PrefixIdParam" "$prefixlistid" $p)
  resourcetype='SGRules'
  deploy_stack $profile $name $resourcetype $template "$p"

}

#################################################################################
# Copyright Notice
# All Rights Reserved.
# All materials (the “Materials”) in this repository are protected by copyright 
# under U.S. Copyright laws and are the property of 2nd Sight Lab. They are provided 
# pursuant to a royalty free, perpetual license the person to whom they were presented 
# by 2nd Sight Lab and are solely for the training and education by 2nd Sight Lab.
#
# The Materials may not be copied, reproduced, distributed, offered for sale, published, 
# displayed, performed, modified, used to create derivative works, transmitted to 
# others, or used or exploited in any way, including, in whole or in part, as training 
# materials by or for any third party.
#
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
################################################################################ 
