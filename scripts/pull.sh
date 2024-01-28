  echo "get repo account number"
  echo "aws sts get-caller-identity --query Account --output text --PROFILE $reporolename"
  repoaccount=$(aws sts get-caller-identity --query Account --output text --PROFILE $reporolename --region $region)

  repo="sandbox"
  pass=$repoaccount'.dkr.ecr.'$region'.amazonaws.com'
  tag="$pass/$repo:$image"

  echo "aws ecr get-login-password --PROFILE $reporolename --region $region | docker login --username AWS --password-stdin $pass"
  aws ecr get-login-password --PROFILE $reporolename --region $region | docker login --username AWS --password-stdin $pass

  echo docker pull $tag
  docker pull $tag

  image=$tag
