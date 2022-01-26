#!/bin/bash
#
# create_image.sh
# ============
#
# Build container image by docker-compose, push the image to Amazon ECR.
# A target repository to push shall be prepared in ECR before pushing image.
#
# Usage:
#     create_image.sh  [Options]
#     create_image.sh  -h|--help
#
# Options:
#   -a, --account ACCOUNT       Specify AWS account ID
#                               (default: get by AWS CLI)
#   -r, --region REGION         Specify a region
#                               (default: get from ~/.aws/config)
#   -n, --name NAME             Specify an image name of the built docker image (same with ecr reporitory name)
#                               (default: nginx-rtmp-kvs)
#   -t, --tag TAG               Specify a tag of the built docker image
#                               (default: latest)
#   -b, --build                 Build docker image
#   -p, --push                  Push docker image to the Amazon ECR

# Function help() shows help
help() {
  awk 'NR > 2 {
    if (/^#/) { sub("^# ?", ""); print }
    else { exit }
  }' $0
}

BUILD=false;
PUSH=false;

while getopts arntbpih-: opt; do
    optarg="${!OPTIND}"
    [[ "$opt" = - ]] && opt="-$OPTARG"

    case "-$opt" in
        -a | --account ) AWS_ACCOUNT_ID="$optarg" ;;
        -r | --region ) REGION="$optarg" ;;
        -n | --name ) IMAGE_NAME="$optarg" ;;
        -t | --tag ) IMAGE_TAG="$optarg" ;;
        -b | --build ) BUILD=true ;;
        -p | --push ) PUSH=true ;;
        -h | --help ) help; exit 1 ;;
        --) break ;;
        -\?) exit 1 ;;
        --*) echo "$0: illegal option -- ${opt##-}" >&2
             exit 1 ;;
    esac
    shift $((OPTIND - 1))
done
shift $((OPTIND - 1))

if [ ! "$BUILD" ] && [ ! "$PUSH" ] ] ; then
  echo "Error: At least -b (build) or -p (push) option is required." 1>&2
  exit 1
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID=`aws sts get-caller-identity | jq .Account | sed 's/"//g'`
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: -a option for AWS_ACCOUNT_ID is required." 1>&2
    exit 1
  fi
fi

if [ -z "$REGION" ]; then
  REGION=`aws configure get region`
  if [ -z "$REGION" ]; then
    echo "Error: -r option for REGION is required." 1>&2
    exit 1
  fi
fi

if [ -z "$IMAGE_NAME" ]; then
  IMAGE_NAME="nginx-rtmp-kvs"
fi

if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "REGION: $REGION"

set -ex

# Build image
if "$BUILD"; then
  echo "IMAGE_NAME: $IMAGE_NAME"
  echo "IMAGE_TAG: $IMAGE_TAG"
  # Pass variables to childen
  export IMAGE_NAME
  export IMAGE_TAG
  docker-compose -f docker-compose.yml build
fi

# Push image to ECR
# Reference: https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/userguide/docker-push-ecr-image.html
if "$PUSH"; then
  aws ecr get-login-password | docker login --username AWS --password-stdin "https://${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
  docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}:${IMAGE_TAG}"
  docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}:${IMAGE_TAG}"
fi
