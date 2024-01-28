#!/bin/bash -e
# https://github.com/tradichel/2sl-jobexecframework/
# awsdeploy/resources/organizations/organizationalunit/organizationalunit_functions.sh
# author: @teriradichel @2ndsightlab
# description: Functions used to deploy an organizationa unit
##############################################################
source resources/organizations/organization/organization_functions.sh
source shared/functions.sh
source shared/validate.sh

get_parent_ou_id(){
  ouname="$1"
  parentname="$2"

  func=${FUNCNAME[0]}

  if [ "$parentname" == "" ] || [ "$parentname" == "root" ]; then parentid=$(get_root_id); 		
  else parentid=$(get_account_number_from_name $parentname); fi
  validate_set $func "parentid $parentname for ou $ouname" $parentid

	if [ "$parentid" == "$parentname" ]; then echo "Invalid parent id: $parentid for ou: $ou parent $parentname"; exit; fi

	echo $parentid
}

#if no parent provided, this function searches
#all the nodes starting from the root to find
#the ou id. Hoping AWS will provide a new action
#to find the OU ID by the OU name instead because
#that would likely execute faster than making all
#these API calls over the network.
get_id(){
	ou_name="$1"
	parent_id="$2"

	#the parent id is not set so start at the root	
	if [ "$parent_id" == "" ]; then parent_id=$(get_root_id)
		#return the root id if the ou_name is root
		if [ "$ou_name" == "root" ]; then echo $parent_id; exit; fi
	fi

	#loop through child nodes for parent
	for n in $(aws organizations list-organizational-units-for-parent --parent-id $parent_id \
      --query 'OrganizationalUnits[*].Name' --output text --PROFILE $PROFILE); do
			if [ "$n" == "$ou_name" ]; then
				#if the current ou name matches the target ou name, return the id
  			id=$(aws organizations list-organizational-units-for-parent --parent-id $parent_id \
     	 		--query 'OrganizationalUnits[?Name == `'$ou_name'`].Id' --output text --PROFILE $PROFILE)
		  	echo $id; exit
			fi
	done
	
	#If we haven't exited yet, we don't have an id yet
	#Loop through the child OUs and use those as the parent id to recursively call the function again
	for pid in $(aws organizations list-organizational-units-for-parent --parent-id $parent_id \
     --query 'OrganizationalUnits[*].Id' --output text --PROFILE $PROFILE); do
		get_ou_id_from_name $ou_name $pid
	done

}

################################################################################
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
