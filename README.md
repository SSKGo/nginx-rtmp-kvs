# nginx-rtmp-kvs

This repository is prepared to deploy Nginx docker container on Amazon ECS which receive video signal in RTMP and send it to Amazon Kinesis Video Streams using "amazon-kinesis-video-streams-producer-sdk-cpp".

```
Video Encoder --- (RTMP) ---> Nginx on Amazon ECS ---> Kinesis Video Streams
```

Reference: https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp

# Get started

## 1. Create repository in ECR

Create target repository in ECR to push docker image before pushing image.
"nginx-rtmp-kvs" is default name of docker image.

## 2. Create and Push docker image

A script to create docker image by docker-compose and push the image to ECR by AWS CLI is prepared. Refer to the help of the script.

```
sh create_image.sh --help
```

## 3. Create IAM role

Create task execution role with "AmazonECSTaskExecutionRolePolicy" and permission to access AWS Systems Manager Parameter Store.

A script to create task by AWS CLI is prepared. Refer to the help of the script.

```
sh create_role.sh --help
```

## 4. Create task definition in ECS

### Environment Variables

Create IAM user which has permission to put media and obtain its AWS_ACCESS_KEY and AWS_SECRET_KEY.

Set the following environment variables in container definitions of task definition of ECS.

| Name           |           | Value                         |
| -------------- | --------- | ----------------------------- |
| AWS_REGION     | Value     | ap-northeast-1                |
| AWS_ACCESS_KEY | ValueFrom | KVS-IAM-Secret_AWS_ACCESS_KEY |
| AWS_SECRET_KEY | ValueFrom | KVS-IAM-Secret_AWS_SECRET_KEY |

Remarks:

- "ap-northeast-1" should be replaced with your target region.
- "KVS-IAM-Secret_AWS_ACCESS_KEY" and "KVS-IAM-Secret_AWS_SECRET_KEY" are examples of parameter name in parameter store. You can change them to any name.

AWS_ACCESS_KEY and AWS_SECRET_KEY are sensitive data. AWS Systems Manager Parameter Store should be used to pass the values to containers in ECS.

Use the following command template to put parameter in parameter store, if required.

```
aws ssm put-parameter \
 --name "KVS-IAM-Secret_AWS_ACCESS_KEY" \
 --value 'Access Key Value' \
 --type "SecureString" \
 --tier Standard

aws ssm put-parameter \
 --name "KVS-IAM-Secret_AWS_SECRET_KEY" \
 --value 'Secret Key Value' \
 --type "SecureString" \
 --tier Standard
```

Reference: [https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/specifying-sensitive-data-tutorial.html](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/specifying-sensitive-data-tutorial.html)

### Port mapping

Set port mapping in container definitions of task definition of ECS.
| Host Port | Container Port | Protocol |
| -------------- | --------- | ----------------------------- |
| 1935 | 1935 | tcp |

## 5. Create cluster in ECS

Create cluster in ECS, if required.

## 6. Create service in the cluster

Create a service using the prepared task definition in the previous steps.
If RTMPS (cryptographic communication) is used, "Network Load Balancer" is recommended to use as TLS endpoint. ("Network Load Balncer" scheme has not been confirmed yet.)

## 7. Create a video stream in KVS

Create a video stream in Kinesis Video Stream.

## 8. Start video stream

Start a video stream.

Server:

```
rtmp(s)://[IP Address]:1935/live
```

Stream key:

```
[Video stream name]
```

# Appendix

## Local debug

```
export IMAGE_NAME="nginx-rtmp-kvs"
export IMAGE_TAG="latest"
docker-compose up --build -d nginx
docker-compose logs -f
docker exec -it [container ID] bin/bash
```

## Access containers running on Fargate through session manager

Update "enableExecuteCommand" of the service to true.

```
aws ecs update-service --cluster [Cluster Name] --service [Service Name] --enable-execute-command
aws ecs describe-services --cluster [Cluster Name] --services [Service Name] | grep enableExecuteCommand
```

Confirm "enableExecuteCommand" become true.

```
"enableExecuteCommand": true
```

Add the following IAM Policy to the task role specified in the task definition.

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    }
  ]
}
```

Recreate a task by updating the service. "Force new deployment" should be checked to recreate the task.

```
aws ecs describe-tasks --cluster [Cluster Name] --tasks [Task Name] | grep enableExecuteCommand
```

Confirm "enableExecuteCommand" is true.

```
"enableExecuteCommand": true
```

The above process is required only once.

Connect the target container.

```
aws ecs execute-command --cluster [Cluster Name] --task [Task Name] --container [Container Name] --interactive --command "/bin/sh"
```
