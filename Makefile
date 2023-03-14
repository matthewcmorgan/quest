default: test

build: 
	docker build -t local:test .

run: 
	docker logs --follow `docker run -itd -p 3000:3000 -p 80:80 local:test`

connect:
	docker run -it -p 3000:3000 local:test sh

test: build

stop:
	docker stop `docker ps -al` || exit 0

clean:
	docker rm -f `docker ps -aq` || exit 0

deploy:
	aws cloudformation validate-template --template-body CloudFormation/Service.yml \
	&& aws cloudformation package --template-file CloudFormation/Service.yml --s3-bucket matthew.morgan.bucket \
	&& aws cloudformation estimate-template-cost --template-body code/quest/packaged.yml \
	&& aws cloudformation deploy --template-file packaged.yml --stack-name mmorgan-ecs-test --capabilities CAPABILITY_NAMED_IAM