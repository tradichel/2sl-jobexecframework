#!/bin/bash -e
# https://github.com/tradichel/2sl-jobexecframework
# awsdeploy/resources/routetable/routetable_functions.sh
# author: @teriradichel @2ndsightlab
# description: deploy route tables
##############################################################

source "shared/functions.sh"
source "shared/validate.sh"

fix_vpc_route_table(){

	vpcname="$1"
	rttype="$2"
	
	echo "Fixing Route Table"
	echo "TODO: Import route table instead..."

  f=${FUNCNAME[0]}
  validate_var $f "vpcname" $vpcname 
	validate_var $f "rttype" $rttype

	vpcid=$(get_vpc_id_by_name $vpcname)

  rtname=$vpcname$rttype'routetable'
	rtstackname=$profile'-ec2-routetable-'$rtname
	exportname='id-ec2-routetable-'$rtname
  newrtid=$(get_stack_export $rtstackname $exportname)

	mainrtid=$(aws ec2 describe-route-tables \
						--filters Name=vpc-id,Values=$vpcid Name=association.main,Values=true \
						--query RouteTables[0].RouteTableId --output text --profile $profile)

  if [ "$mainrtid" != "$newrtid" ]; then		
  	echo "Updating VPC: $vpcid main route table $mainrtid to new route table: $newrtid"
		associd=$(aws ec2 describe-route-tables \
					--filters Name=vpc-id,Values=$vpcid Name=association.main,Values=true \
					--query RouteTables[0].Associations[0].RouteTableAssociationId --output text --profile $profile)
		aws ec2 replace-route-table-association --association-id $associd --route-table-id $newrtid --profile $profile
		aws ec2 delete-route-table --route-table-id $mainrtid --profile $profile
	fi

	echo "$vpcname Default route table removed and replaced with new route table $newrtid."

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
