AWS_ACCOUNT_ID := 324320755747
AWS_REGION := us-west-2
ECR_REPO_NAME := mmorgan-ecs-test
CLUSTER_NAME := mmorgan-ecs-test
SERVICE_NAME := mmorgan-ecs-test
TASK_NAME := mmorgan-ecs-test
TARGET_GROUP_NAME := mmorgan-ecs-test
IMAGE_NAME := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):latest
CONTAINER_NAME := mmorgan-ecs-test
LOAD_BALANCER_NAME := mmorgan-ecs-test
CERTIFICATE_ARN := <arn_of_your_tls_certificate>

.PHONY: all build tag push configure-cluster create-repository create-task register-service create-target-group

all: build tag push configure-cluster create-repository create-task register-service create-target-group

default: test destroy deploy

run: 
	docker logs --follow `docker run -itd -p 3000:3000 -p 80:80 local:test`

connect:
	docker run -it -p 3000:3000 local:test sh

test: build

stop:
	docker stop `docker ps -al` || exit 0

clean:
	docker rm -f `docker ps -aq` || exit 0

deploy: package
	aws cloudformation deploy --template-file packaged.yml --stack-name mmorgan-ecs-test --capabilities CAPABILITY_NAMED_IAM

package:
	aws cloudformation package --template-file CloudFormation/Infra.yml --s3-bucket matthew.morgan.bucket --output-template-file packaged.yml

validate: package
	aws cloudformation validate-template --template-body file://packaged.yml

destroy:
	aws cloudformation delete-stack --stack-name mmorgan-ecs-test

###
# HERE BE DRAGONS! GO FORTH WITH CAUTION!
# Manual steps to build resources instead of cloudformation
# Build the Docker image.
build:
	@echo "Building the Docker image..."
	docker build -t $(IMAGE_NAME) .

# Tag the Docker image with the ECR repository URL.
tag:
	@echo "Tagging the Docker image..."
	docker tag $(IMAGE_NAME) $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):latest

# Push the Docker image to the ECR repository.
push:
	@echo "Pushing the Docker image to ECR..."
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):latest

# Create the ECS cluster.
configure-cluster:
	@echo "Configuring the ECS cluster..."
	aws ecs create-cluster --cluster-name $(CLUSTER_NAME)

# Create the ECR repository.
create-repository:
	@echo "Creating the ECR repository..."
	aws ecr create-repository --repository-name $(ECR_REPO_NAME)

# Create the ECS task definition.
create-task:
	@echo "Creating the ECS task definition..."
	aws ecs register-task-definition \
	    --family $(TASK_NAME) \
	    --task-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/my-task-role \
	    --execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/my-task-role \
	    --network-mode awsvpc \
	    --container-definitions '[{"name": "$(CONTAINER_NAME)","image": "$(IMAGE_NAME)","memoryReservation": 512}]'

# Create the ECS service with load balancing and TLS.
register-service:
	@echo "Creating the ECS service..."
	aws ecs create-service \
	    --service-name $(SERVICE_NAME) \
	    --cluster $(CLUSTER_NAME) \
	    --task-definition $(TASK_NAME) \
	    --desired-count 1 \
	    --launch-type FARGATE \
	    --load-balancers '[{"loadBalancerName": "$(LOAD_BALANCER_NAME)","targetGroupArn": "$(TARGET_GROUP_ARN)","containerName": "$(CONTAINER_NAME)","containerPort": 80}]' \
	    --role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/my-service-role \
	    --network-configuration awsvpcConfiguration={subnets=[<your_subnet_ids>],securityGroups=[<your_security_group_id>],assignPublicIp=ENABLED} \
        --platform-version 1.4.0 \
        --force-new-deployment \
        --health-check-grace-period-seconds 90 \
        --propagate-tags \
        --deployment-controller '{"type": "ECS"}'

create-target-group:
	@echo "Creating the Elastic Load Balancer target group..."
	aws elbv2 create-target-group \
	    --name $(TARGET_GROUP_NAME) \
	    --protocol HTTP \
	    --port 80 \
	    --vpc-id <your_vpc_id>
	@echo "Registering the ECS service with the target group..."
	TARGET_GROUP_ARN=`aws elbv2 describe-target-groups --name $(TARGET_GROUP_NAME) --query 'TargetGroups[0].TargetGroupArn' --output text` && \
    SEARCH_STRING=$$(echo $(IMAGE_NAME) | sed 's/\//\\\//g') && \
    TASK_DEFINITION_REVISION_ARN=`aws ecs list-task-definitions --family $(TASK_NAME) --query 'taskDefinitionArns[0]' --output text` && \
    CONTAINER_PORT=`aws ecs describe-task-definition --task-definition $${TASK_DEFINITION_REVISION_ARN} --query 'taskDefinition.containerDefinitions[0].portMappings[0].containerPort' --output text` && \
    CONTAINER_DEFINITION=`aws ecs describe-task-definition --task-definition $${TASK_DEFINITION_REVISION_ARN} --query 'taskDefinition.containerDefinitions[0]'` && \
    sed "s/%%CONTAINER_DEFINITION%%/$$(echo $$CONTAINER_DEFINITION | sed 's/"/\\\"/g')/" target-group.json | sed "s/%%Docker_Image%%/$$SEARCH_STRING/" | sed "s/%%Container_Port%%/$$CONTAINER_PORT/" > updated-target-group.json && \
    aws elbv2 create-listener \
        --load-balancer-arn $(LOAD_BALANCER_ARN) \
        --protocol HTTPS \
        --port 443 \
        --certificates CertificateArn=$(CERTIFICATE_ARN) \
        --default-actions Type=forward,TargetGroupArn=$$TARGET_GROUP_ARN \
	&& aws elbv2 create-rule \
        --listener-arn `aws elbv2 describe-listeners --load-balancer-arn $(LOAD_BALANCER_ARN) --query 'Listeners[0].ListenerArn' --output text` \
        --priority 1 \
        --conditions Field=path-pattern,Values='*' \
        --actions Type=forward,TargetGroupArn=$$TARGET_GROUP_ARN
	@echo "Finished creating the Elastic Load Balancer and Target Group."